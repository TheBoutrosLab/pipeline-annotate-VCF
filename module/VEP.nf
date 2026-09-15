include { generate_standard_filename } from "${moduleDir}/../external/pipeline-Nextflow-module/modules/common/generate_standardized_filename/main.nf"

process annotate_VCF_VEP {
    container params.docker_image_VEP
    containerOptions "--env HOME=/home/\${USER} ${params.container_mount_flag} ${params.vep_cache}:/home/\${USER}/.vep"

    publishDir path: "${META.workflow_output_dir}/output",
        pattern: "*.tsv",
        mode: "copy"
    ext log_dir: { "${META.log_dir_prefix}/${task.process.split(':')[-1]}" }

    input:
    val META
    tuple path(vcf), path(vcf_index)
    path genome_fasta
    path genome_fasta_index
    path annotation_gtf
    path annotation_gtf_index

    output:
    path output_file, emit: 'vep_tsv'

    script:
    output_filename = generate_standard_filename(
        "VEP-${params.VEP_version}",
        params.dataset_id,
        params.sample_id,
        [:]
    )
    output_file = "${output_filename}.tsv"

    """
    set -euo pipefail

    vep \
        --offline \
        --cache \
        --check_ref \
        --no_stats \
        --fork ${task.cpus} \
        --buffer_size 10000 \
        --distance 0 \
        --assembly ${params.genome_assembly_version} \
        --no_intergenic \
        --chr ${params.chromosomes} \
        -i ${vcf} \
        -o ${output_file} \
        --fasta ${genome_fasta} \
        --custom ${annotation_gtf},${params.genome_annotation_version},gtf
    """
}

process filter_annotation_VEP {
    container params.docker_image_VEP
    containerOptions "--e HOME=/home/\${USER} ${params.container_mount_flag} ${params.vep_cache}:/home/\${USER}/.vep"

    publishDir path: "${META.workflow_output_dir}/output",
        pattern: "*.tsv",
        mode: "copy"
    ext log_dir: { "${META.log_dir_prefix}/${task.process.split(':')[-1]}" }

    input:
    val META
    path vep_tsv

    output:
    path filtered_tsv, emit: 'filtered_tsv'

    script:
    output_filename = generate_standard_filename(
        "VEP-${params.VEP_version}",
        params.dataset_id,
        params.sample_id,
        [additional_information: "filtered"]
    )
    filtered_tsv = "${output_filename}.txt"
    """
    filter_vep \
        --force_overwrite \
        -i ${vep_tsv} \
        -o ${filtered_tsv} \
        --filter "Source = ${params.genome_annotation_version}"
    """
}
