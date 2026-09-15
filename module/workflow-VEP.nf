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
- genome reference version: ${params.genome_reference_version}
- genome FASTA: ${params.genome_fasta}
- anntoation GTF: ${params.annotation_gtf}
- chromosomes: ${params.chromosomes}
"""


include { annotate_VCF_VEP; filter_annotation_VEP } from "${moduleDir}/VEP"
include { generate_sha512sum; compress_VCF_bgzip } from "${moduleDir}/common"

workflow workflow_VEP {
    take:
        vcf
        vcf_index

    main:
        annotate_VCF_VEP(
            vcf,
            vcf_index,
            params.genome_fasta,
            "${params.genome_fasta}.fai",
            params.annotation_gtf,
            "${params.annotation_gtf}.tbi"
            )
        filter_annotation_VEP(
            annotate_VCF_VEP.out.vep_tsv
            )
        compress_VCF_bgzip(filter_annotation_VEP.out.filtered_tsv)
        file_for_sha512 = compress_VCF_bgzip.out.gz
        generate_sha512sum(file_for_sha512)
}
