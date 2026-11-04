include { generate_standard_filename } from "${moduleDir}/../external/pipeline-Nextflow-module/modules/common/generate_standardized_filename/main.nf"

process annotate_VCF_VEP {
    container params.docker_image_VEP

    publishDir path: "${META.workflow_output_dir}/output",
        pattern: "*.tsv",
        mode: "copy",
        failOnError: false
    ext log_dir: { "${META.log_dir_prefix}/${task.process.split(':')[-1]}" },
        containerOptions: { "--home /home/\${USER} ${params.container_mount_flag} ${META.vep_cache}:/home/\${USER}/.vep" }

    input:
    val META
    tuple path(vcf), path(vcf_index)
    path genome_fasta
    path genome_fasta_index
    path annotation_gtf          // [] when params.VEP_custom_gtf is false
    path annotation_gtf_index    // [] when params.VEP_custom_gtf is false

    output:
    path output_file, emit: 'vep_output'

    script:
    output_filename = generate_standard_filename(
        "VEP-${params.VEP_version}",
        params.dataset_id,
        params.sample_id,
        [:]
    )
    output_ext = params.VEP_output_format == 'vcf' ? 'vcf' : 'tsv'
    output_file = "${output_filename}.${output_ext}"

    arg_format = params.VEP_output_format == 'vcf' ? '--vcf' : ''
    arg_restrict = params.VEP_restrict_output ? '--distance 0 --no_intergenic' : ''
    arg_chr = params.chromosomes ? "--chr ${params.chromosomes}" : ''
    arg_custom = params.VEP_custom_gtf ? "--custom ${annotation_gtf},${params.genome_annotation_version},gtf" : ''
    arg_extra_options = "${params.VEP_extra_options}"

    """
    set -euo pipefail

    vep \
        --offline \
        --cache \
        --check_ref \
        --no_stats \
        --fork ${task.cpus} \
        --buffer_size 10000 \
        --assembly ${params.genome_assembly_version} \
        -i ${vcf} \
        -o ${output_file} \
        --fasta ${genome_fasta} \
        $arg_format \
        $arg_restrict \
        $arg_chr \
        $arg_custom \
        $arg_extra_options
    """
}

process filter_annotation_VEP {
    container params.docker_image_VEP

    publishDir path: "${META.workflow_output_dir}/output",
        pattern: "*.txt",
        mode: "copy",
        failOnError: false
    ext log_dir: { "${META.log_dir_prefix}/${task.process.split(':')[-1]}" },
        containerOptions: { "--home /home/\${USER} ${params.container_mount_flag} ${META.vep_cache}:/home/\${USER}/.vep" }

    input:
    val META
    path vep_output

    output:
    path filtered_output, emit: 'filtered_output'

    script:
    output_filename = generate_standard_filename(
        "VEP-${params.VEP_version}",
        params.dataset_id,
        params.sample_id,
        [additional_information: "filtered"]
    )
    // VCF output is published after bgzip/tabix in workflow_VEP; tab output is published here as *.txt
    // NOTE: filtering VCF output on the custom GTF source (`Source = ...`) has not been tested
    output_ext = params.VEP_output_format == 'vcf' ? 'vcf' : 'txt'
    filtered_output = "${output_filename}.${output_ext}"
    arg_format = params.VEP_output_format == 'vcf' ? '--format vcf' : ''
    """
    set -euo pipefail

    filter_vep \
        --force_overwrite \
        $arg_format \
        -i ${vep_output} \
        -o ${filtered_output} \
        --filter "Source = ${params.genome_annotation_version}"
    """
}
