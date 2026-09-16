#!/usr/bin/env nextflow

nextflow.enable.dsl=2


log.info """\
        =========================
         A N N O T A T E - V C F
        =========================
        Boutros Lab

        Current Configuration:
        - pipeline:
            name: ${workflow.manifest.name}
            version: ${workflow.manifest.version}

        - input:
            sample_id: ${params.sample_id}
            algorithm: ${params.algorithm}
            input.vcf: ${params.input.vcf}
            genome_version: ${params.genome_version}
            reference: ${params.reference_fasta}

        - output:
            output_dir: ${params.output_dir_base}
            output_log_dir: ${params.log_output_dir}

        - other options:
            save_intermediate_files: ${params.save_intermediate_files}

        Tools Used:
            SnpEff: ${params.docker_image_SnpEff}

        ------------------------------------
        Starting workflow...
        ------------------------------------
        """
        .stripIndent()

include { run_validate_PipeVal } from './external/pipeline-Nextflow-module/modules/PipeVal/validate/main.nf'
include { indexFile } from './external/pipeline-Nextflow-module/modules/common/indexFile/main.nf'
include { compress_index_VCF } from './external/pipeline-Nextflow-module/modules/common/index_VCF_tabix/main.nf'
include { normalize_VCF_BCFtools } from './module/common.nf'
include { workflow_SnpEff } from './module/workflow-SnpEff.nf'
include { workflow_Funcotator } from './module/workflow-Funcotator.nf'
include { workflow_VEP } from './module/workflow-VEP.nf'


// Main workflow here
workflow {
    Channel.from( params.input.vcf )
        .map{ raw_param_vcf ->
            [
                "vcf": raw_param_vcf,
                "index": indexFile(raw_param_vcf)
            ]
        }
        .set { ich }

    /**
    *   Input validation
    */
    base_meta = Channel.value([
        'log_output_dir': params.log_output_dir,
        'output_dir': params.output_dir_base,
        'output_dir_base': params.output_dir_base
    ])

    module_meta = base_meta.map{ base_m ->
        base_m + [
            'log_output_dir': "${params.log_output_dir}/process-log"
        ]
    }

    ich.map{ sample -> [sample.vcf, sample.index] }
        .flatten()
        .set{ input_ch_validate }

    // Validate input files
    run_validate_PipeVal(
        module_meta.combine(input_ch_validate)
    )

    // Capture validation results
    run_validate_PipeVal.out.validation_result
        .collectFile(
            name: 'input_validation.txt', newLine: true,
            storeDir: "${params.output_dir_base}/validation"
        )


    /**
    *   Normalize VCF
    */
    bcftools_meta = base_meta.map{ base_m ->
        base_m + [
            "workflow_output_dir": "${params.output_dir_base}/BCFtools-${params.BCFtools_version}",
            "log_dir_prefix": "BCFtools-${params.BCFtools_version}"
        ]
    }

    ich.set{ input_ch_annotate }

    if (!params.skip_normalization) {
        normalize_VCF_BCFtools(
            bcftools_meta,
            ich.map{ sample -> [sample.vcf, sample.index] }
        )

        compress_index_VCF(
            bcftools_meta.combine(normalize_VCF_BCFtools.out.norm_vcf)
                .map{ n_vcf -> [
                    n_vcf[0] + [
                        "output_dir": n_vcf[0].workflow_output_dir,
                        "log_output_dir": "${n_vcf[0].log_output_dir}/process-log/${n_vcf[0].log_dir_prefix}",
                        "id": params.sample_id
                    ],
                    n_vcf[1]
                ]}
        )

        compress_index_VCF.out.index_out
            .map{ compressed_sample -> ["vcf": compressed_sample[1], "index": compressed_sample[2]] }
            .set{ input_ch_annotate }
    }


    /**
    *   SnpEff
    */
    if ('SnpEff' in params.algorithm) {
        snpeff_meta = base_meta.map{ base_m ->
            base_m + [
                "workflow_output_dir": "${params.output_dir_base}/SnpEff-${params.SnpEff_version}",
                "log_dir_prefix": "SnpEff-${params.SnpEff_version}"
            ]
        }

        workflow_SnpEff(
            snpeff_meta,
            input_ch_annotate
        )
    }

    /**
    *   Funcotator
    */
    if ('Funcotator' in params.algorithm) {
        funcotator_meta = base_meta.map{ base_m ->
            base_m + [
                "workflow_output_dir": "${params.output_dir_base}/Funcotator-${params.GATK_version}",
                "log_dir_prefix": "Funcotator-${params.GATK_version}"
            ]
        }

        workflow_Funcotator(
            funcotator_meta,
            input_ch_annotate
        )
    }

    /**
    *   VEP
    */
    if ('VEP' in params.algorithm) {
        vep_meta = base_meta.map{ base_m ->
            base_m + [
                "workflow_output_dir": "${params.output_dir_base}/VEP-${params.VEP_version}",
                "log_dir_prefix": "VEP-${params.VEP_version}"
            ]
        }

        workflow_VEP(
            vep_meta,
            input_ch_annotate
        )
    }

    workflow.onComplete = {
        WorkflowFinalizer.completeWorkflow(workflow, params);
    }
}
