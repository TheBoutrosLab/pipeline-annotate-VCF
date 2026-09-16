nextflow.enable.dsl=2

log.info """\
====================================
            S N P E F F
====================================
Docker Images:
- docker_image_SnpEff: ${params.docker_image_SnpEff}
- docker_image_BCFtools: ${params.docker_image_BCFtools}
SnpSift Options:
- SnpSift Annotated Database: ${params.SnpSift_annotate_database}
"""

include { indexFile } from '../external/pipeline-Nextflow-module/modules/common/indexFile/main.nf'
include { annotate_VCF_SnpEff; annotate_VCF_SnpSift } from './SnpEff'
include { compress_index_VCF } from '../external/pipeline-Nextflow-module/modules/common/index_VCF_tabix/main.nf'
include { generate_checksum_PipeVal } from '../external/pipeline-Nextflow-module/modules/PipeVal/generate-checksum/main.nf'

workflow workflow_SnpEff {
    take:
    META
    input_ch_sample

    main:
    Channel.of(params.SnpSift_annotate_database)
        .set{ input_ch_snpsift_annotate_database_vcf }

    List snpsift_annotate_database_vcf_index = []
    params.SnpSift_annotate_database.each{ database ->
        snpsift_annotate_database_vcf_index << indexFile(database)
    }

    Channel.of(snpsift_annotate_database_vcf_index)
        .set{ input_ch_snpsift_annotate_database_vcf_index }

    input_ch_annotate_snpsift = input_ch_sample.map{ sample -> sample.vcf }
    input_ch_index = Channel.empty()

    if (!params.skip_SnpEff) {
        annotate_VCF_SnpEff(
            META,
            input_ch_sample.map{ sample -> [sample.vcf, sample.index] },
            params.SnpEff_data_dir
        )

        input_ch_annotate_snpsift = annotate_VCF_SnpEff.out.snpeff_vcf
        input_ch_index = input_ch_index.mix(annotate_VCF_SnpEff.out.snpeff_vcf)
    }

    annotate_VCF_SnpSift(
        META,
        input_ch_annotate_snpsift,
        input_ch_snpsift_annotate_database_vcf,
        input_ch_snpsift_annotate_database_vcf_index
    )

    input_ch_index = input_ch_index.mix(annotate_VCF_SnpSift.out.snpsift_vcf)

    compress_index_VCF(
        META.combine(input_ch_index)
            .map{ s_out -> [
                s_out[0] + [
                    "output_dir": s_out[0].workflow_output_dir,
                    "log_output_dir": "${s_out[0].log_output_dir}/process-log/${s_out[0].log_dir_prefix}",
                    "id": "${params.sample_id}-SnpEff",
                    "is_output_file": true
                ],
                s_out[1]
            ]}
    )

    generate_checksum_PipeVal(
        META.combine(compress_index_VCF.out.index_out.map{ indexed -> [indexed[1], indexed[2]] }.flatten())
            .map{ c_out -> [
                c_out[0] + [
                    "output_dir": "${c_out[0].output_dir_base}/output",
                    "checksum_alg": "sha512",
                    "docker_image": params.docker_image_validate,
                    "log_output_dir": "${c_out[0].log_output_dir}/process-log/${c_out[0].log_dir_prefix}"
                ],
                c_out[1]
            ]}
    )
}
