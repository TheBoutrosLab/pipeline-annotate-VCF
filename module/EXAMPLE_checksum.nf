/**
*   Nextflow module for calculating SHA512 checksum
*
*   @input META val Dictionary of metadata for running process; any given metadata will be treated as immutable and passed through the process
*       Available key definitions:
*           output_dir (required): String
*   @input  file_for_calc    path    File to calculate checksum for
*/
process run_command_Tool {
    container "ubuntu:25.04"
    publishDir path: "${META.output_dir}",
      mode: "copy",
      pattern: "*.sha512",
      saveAs: { filename -> (filename.endsWith(".bai.sha512") && !filename.endsWith(".bam.bai.sha512")) ? "${file(file(filename).baseName).baseName}.bam.bai.sha512" : "${filename}"}

    ext log_dir_suffix: { "/${task.process.split(':')[-1]}-${task.index}" }

    input:
    tuple val(META), path(file_for_calc)

    output:
    tuple val(META), path("*.sha512"), emit: sha512_sum

    script:
    """
    set -euo pipefail
    sha512sum ${file_for_calc} > ${file_for_calc}.sha512
    """
}
