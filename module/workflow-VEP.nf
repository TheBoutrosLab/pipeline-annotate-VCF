log.info """\
====================================
               V E P
====================================
Docker Images:
- docker_image_VEP: ${params.docker_image_VEP}
VEP Options:
- VEP cache: ${params.vep_cache}
- genome assembly version: ${params.genome_assembly_version}
- genome reference version: ${params.genome_version}
- genome FASTA: ${params.genome_fasta}
- anntoation GTF: ${params.annotation_gtf}
- chromosomes: ${params.chromosomes}
- output format: ${params.VEP_output_format}
- custom GTF annotation: ${params.VEP_custom_gtf}
- restrict output: ${params.VEP_restrict_output}
- extra options: ${params.VEP_extra_options}
"""


include { annotate_VCF_VEP; filter_annotation_VEP } from "./VEP.nf"
include { compress_index_VCF } from '../external/pipeline-Nextflow-module/modules/common/index_VCF_tabix/main.nf'
include { generate_checksum_PipeVal } from '../external/pipeline-Nextflow-module/modules/PipeVal/generate-checksum/main.nf'

workflow workflow_VEP {
    take:
    META
    input_ch_sample

    main:
    // Stage the custom GTF only when it is used
    annotation_gtf = params.VEP_custom_gtf ? params.annotation_gtf : []
    annotation_gtf_index = params.VEP_custom_gtf ? "${params.annotation_gtf}.tbi" : []

    annotate_VCF_VEP(
        META,
        input_ch_sample.map{ sample -> [sample.vcf, sample.index] },
        params.genome_fasta,
        "${params.genome_fasta}.fai",
        annotation_gtf,
        annotation_gtf_index
    )

    final_ch = annotate_VCF_VEP.out.vep_output

    if (params.VEP_custom_gtf) {
        filter_annotation_VEP(
            META,
            final_ch
        )

        final_ch = filter_annotation_VEP.out.filtered_output
    }

    checksum_ch = final_ch

    if (params.VEP_output_format == 'vcf') {
        compress_index_VCF(
            META.combine(final_ch)
                .map{ v_out -> [
                    v_out[0] + [
                        "output_dir": v_out[0].workflow_output_dir,
                        "log_output_dir": "${v_out[0].log_output_dir}/process-log/${v_out[0].log_dir_prefix}",
                        "id": "${params.sample_id}-VEP",
                        "is_output_file": true
                    ],
                    v_out[1]
                ]}
        )

        checksum_ch = compress_index_VCF.out.index_out
            .map{ indexed -> [indexed[1], indexed[2]] }
            .flatten()
    }

    generate_checksum_PipeVal(
        META.combine(checksum_ch)
            .map{ f_out -> [
                f_out[0] + [
                    "output_dir": "${f_out[0].workflow_output_dir}/output",
                    "checksum_alg": "sha512",
                    "docker_image": params.docker_image_validate,
                    "log_output_dir": "${f_out[0].log_output_dir}/process-log/${f_out[0].log_dir_prefix}"
                ],
                f_out[1]
            ]}
    )
}
