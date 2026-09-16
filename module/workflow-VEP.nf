nextflow.enable.dsl=2

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
"""


include { annotate_VCF_VEP; filter_annotation_VEP } from "./VEP.nf"
include { generate_checksum_PipeVal } from '../external/pipeline-Nextflow-module/modules/PipeVal/generate-checksum/main.nf'

workflow workflow_VEP {
    take:
    META
    input_ch_sample

    main:
    annotate_VCF_VEP(
        META,
        input_ch_sample.map{ sample -> [sample.vcf, sample.index] },
        params.genome_fasta,
        "${params.genome_fasta}.fai",
        params.annotation_gtf,
        "${params.annotation_gtf}.tbi"
    )

    filter_annotation_VEP(
        META,
        annotate_VCF_VEP.out.vep_tsv
    )

    generate_checksum_PipeVal(
        META.combine(filter_annotation_VEP.out.filtered_tsv)
            .map{ f_out -> [
                f_out[0] + [
                    "output_dir": "${f_out[0].output_dir_base}/output",
                    "checksum_alg": "sha512",
                    "docker_image": params.docker_image_valdate,
                    "log_output_dir": "${f_out[0].log_output_dir}/process-log/${f_out[0].log_dir_prefix}"
                ],
                f_out[1]
            ]}
    )
}
