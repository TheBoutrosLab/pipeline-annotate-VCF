nextflow.enable.dsl=2

log.info """\
====================================
      F U N C O T A T O R
====================================
Docker Images:
- docker_image_GATK: ${params.docker_image_GATK}
- docker_image_BCFtools: ${params.docker_image_BCFtools}
"""

include { run_Funcotator_GATK } from './Funcotator.nf'
include { compress_index_VCF } from '../external/pipeline-Nextflow-module/modules/common/index_VCF_tabix/main.nf'
include { generate_checksum_PipeVal } from '../external/pipeline-Nextflow-module/modules/PipeVal/generate-checksum/main.nf'


workflow workflow_Funcotator {
    take:
    META
    input_ch_sample

    main:
    run_Funcotator_GATK(
        META,
        input_ch_sample.map{ sample -> [sample.vcf, sample.index] },
        params.reference,
        params.reference_index,
        params.reference_dict,
        params.Funcotator_data_source
    )

    input_ch_compress_index = Channel.empty()
    if ('VCF' == params.Funcotator_output_format) {
        input_ch_compress_index = run_Funcotator_GATK.out.vcf
    } else {
        input_ch_compress_index = run_Funcotator_GATK.out.maf
    }

    compress_index_VCF(
        META.combine(input_ch_compress_index)
            .map{ f_out -> [
                f_out[0] + [
                    "output_dir": f_out[0].workflow_output_dir,
                    "log_output_dir": "${f_out[0].log_output_dir}/process-log/${f_out[0].log_dir_prefix}",
                    "id": "${params.sample_id}-Funcotator",
                    "is_output_file": true
                ],
                f_out[1]
            ]}
    )

    generate_checksum_PipeVal(
        META.combine(compress_index_VCF.out.index_out.flatten())
            .map{ c_out -> [
                c_out[0] + [
                    "output_dir": "${c_out[0].output_dir_base}/output",
                    "checksum_alg": "sha512",
                    "docker_image": params.docker_image_valdate,
                    "log_output_dir": "${c_out[0].log_output_dir}/process-log/${c_out[0].log_dir_prefix}"
                ],
                c_out[1]
            ]}
    )
}
