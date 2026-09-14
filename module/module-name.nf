include { generate_standard_filename } from '../external/pipeline-Nextflow-module/modules/common/generate_standardized_filename/main.nf'

/**
*   Nextflow module template
*
*   @input META val Dictionary of metadata for running process; any given metadata will be treated as immutable and passed through the process
*       Available key definitions:
*           workflow_output_dir (required): String
*
*   @input  <name>  <type>  <description>
*   @params <name>  <type>  <description>
*   @output <name>  <type>  <description>
*/
process tool_name_command_name {
    container params.docker_image_name

    // if setting resources via label (see base.config), set label here
    label "process_high"

    // remove task.index extension if not needed
    publishDir path: "${META.workflow_output_dir}/output",
        pattern: "<file name pattern>",
        mode: "copy",
        enabled: true

    // Process logs (the `.command.*` files) will be automatically saved as
    // `tool_name_command_name/log.command.*` due to
    // methods.setup_process_afterscript(). The folder can be customized
    // per-process to add a suffix distinguishing multiple runs of the same
    // process:

    // ext log_dir_suffix: { "-${variable_name}" }

    // Additional directives here
    
    input:
        val(META)
        tuple val(orig_id), val(id), path(path), val(sample_type)
        val(variable_name)

    output:
        tuple val(META), path("${variable_name}.command_name.file_extension"), emit: output_tag

    script:
    output_filename = generate_standard_filename("SAMtools-${params.samtools_version}",
    params.dataset_id,
    id,
    [:])

    """
    # make sure to specify pipefail to make sure process correctly fails on error
    set -euo pipefail

    # the script should ideally only have call to a single tool
    # to make the command more human readable:
    #  - seperate components of the call out on different lines
    #  - when possible be explict with command options, spelling out their long names
    tool_name \
        command_name \
        --option_1_long_name ${id} \
        --input ${path} \
        --output ${variable_name}.command_name.file_extension
    """
}
