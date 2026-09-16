include { generate_standard_filename } from '../external/pipeline-Nextflow-module/modules/common/generate_standardized_filename/main.nf'

process annotate_VCF_SnpEff {
    container params.docker_image_SnpEff
    publishDir path: "${META.workflow_output_dir}/intermediate/${task.process.replace(':','/')}",
        pattern: "*.vcf.gz",
        mode: "copy",
        enabled: params.save_intermediate_files
    publishDir path: "${META.workflow_output_dir}/output",
        pattern: "*.{html,txt}",
        mode: "copy"
    ext log_dir: { "${META.log_dir_prefix}/${task.process.split(':')[-1]}" }

    input:
    val META
    tuple path(vcf), path(vcf_index)
    path SnpEff_data_dir

    output:
    path "*.vcf.gz", emit: snpeff_vcf
    path "*.{html,txt}"

    script:
    download = params.SnpEff_download ? '' : '-nodownload'
    output_filename = generate_standard_filename("SnpEff-${params.SnpEff_version}",
        params.dataset_id,
        params.sample_id,
        [:])

    """
    set -euo pipefail
    snpEff -Xmx${(task.memory - params.command_mem_diff).getMega()}m \
        ${download} \
        -dataDir ${params.SnpEff_data_dir} \
        ${params.genome_version} \
        ${vcf} \
        -s ${output_filename}.html \
        | bgzip > ${output_filename}.vcf.gz
    """
}

process annotate_VCF_SnpSift {
    container params.docker_image_SnpEff
    publishDir path: "${META.workflow_output_dir}/intermediate/${task.process.replace(':','/')}",
        pattern: "*.vcf.gz",
        mode: "copy",
        enabled: params.save_intermediate_files
    ext log_dir: { "${META.log_dir_prefix}-${database_names_string}/${task.process.split(':')[-1]}" }

    input:
    val META
    path vcf
    path annotate_database_list
    path annotate_database_index_list

    output:
    path "*.vcf.gz", emit: snpsift_vcf

    script:
    def script_content = ""
    def database_name_list = []
    def intermediate_file_list = []

    annotate_database_list.each{ database ->
        def database_name = "${file(database).baseName.split(/\./)[0]}"
        database_name_list << database_name
        intermediate_file_list << "intermediate_${database_name}.vcf.gz"
        }
    //combine database names for final output filename
    def database_names_string = database_name_list.join('_')

    def final_output_filename = generate_standard_filename("SnpSift-${params.SnpEff_version}",
        params.dataset_id,
        params.sample_id,
        [additional_information:"${database_names_string}"])
    final_output_filename = "${final_output_filename}.vcf.gz"

    //final final name should not be intermediate
    intermediate_file_list[-1] = final_output_filename
    def input_file = vcf
    //generate commands
    annotate_database_list.eachWithIndex { database, index ->
        def output_file = intermediate_file_list[index]
        script_content += """
            SnpSift -Xmx${(task.memory - params.command_mem_diff).getMega()}m annotate \
            ${database} \
            ${input_file} \
            | bgzip > ${output_file}
            """
        input_file = output_file
        }
    //remove intermediates
    intermediate_file_list.each { filename ->
        if(filename != final_output_filename) {
            script_content += """
                rm -f ${filename}
                """
            }
    }
    """
    set -euo pipefail
    ${script_content}
    """
}
