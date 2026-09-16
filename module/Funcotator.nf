include { generate_standard_filename } from '../external/pipeline-Nextflow-module/modules/common/generate_standardized_filename/main.nf'

process run_Funcotator_GATK {
    container params.docker_image_GATK
    publishDir path: "${META.workflow_output_dir}/intermediate/${task.process.replace(':','/')}",
        pattern:"*.{vcf,maf}",
        mode: "copy",
        enabled: params.save_intermediate_files
    ext log_dir: { "${META.log_dir_prefix}/${task.process.split(':')[-1]}" }

    input:
    val META
    tuple path(vcf), path(vcf_index)
    path reference
    path reference_index
    path reference_dict
    path Funcotator_data_source

    output:
    path("*.vcf"), emit: vcf optional true
    path("*.maf"), emit: maf optional true

    script:
    output_filename = generate_standard_filename("Funcotator-${params.GATK_version}",
        params.dataset_id,
        params.sample_id,
        [:])

    arg_extra_options = "${params.Funcotator_extra_options}"
    arg_conversion = params.Funcotator_b37_to_hg19_conversion ? "--force-b37-to-hg19-reference-contig-conversion" : ""

    """
    set -euo pipefail
    gatk --java-options \"-Xmx${(task.memory - params.command_mem_diff).getMega()}m\" Funcotator \
        --variant ${vcf} \
        --reference ${reference} \
        --ref-version ${params.genome_version} \
        --data-sources-path ${params.Funcotator_data_source} \
        --output ${output_filename}.${params.Funcotator_output_format.toLowerCase()} \
        --output-file-format ${params.Funcotator_output_format} \
        $arg_conversion \
        $arg_extra_options
    """
}
