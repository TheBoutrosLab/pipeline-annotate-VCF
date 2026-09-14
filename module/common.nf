include { generate_standard_filename } from '../external/pipeline-Nextflow-module/modules/common/generate_standardized_filename/main.nf'

log.info """\
====================================
          C O M M O N
====================================
Docker Images:
- docker_image_samtools: ${params.docker_image_samtools}
- docker_image_BCFtools: ${params.docker_image_BCFtools}
"""


process normalize_VCF_BCFtools {
    container params.docker_image_BCFtools
    publishDir path: "${META.workflow_output_dir}/output",
                mode: "copy",
                pattern: "*.vcf.gz"
    ext log_dir: { "${META.log_dir_prefix}/${task.process.split(':')[-1]}" }

    input:
        val META
        tuple path(vcf), path(vcf_index)

    output:
        path("*.vcf.gz"), emit: norm_vcf

    script:
    args_view = params.bcftools_view_options ?: "--trim-alt-alleles"
    args_norm = params.bcftools_norm_options ?: "-a -m +any"
    output_filename = generate_standard_filename("BCFtools-${params.BCFtools_version}",
        params.dataset_id,
        params.sample_id,
        [additional_information:"normalized"])
    """
    set -euo pipefail
    bcftools view ${vcf} ${args_view} | bcftools norm ${args_norm} -O z -o ${output_filename}.vcf.gz
    """
}
