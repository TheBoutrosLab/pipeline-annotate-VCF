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
            reference: ${params.reference}

        - output:
            output_dir: ${params.output_dir_base}
            output_log_dir: ${params.output_log_dir}

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



    workflow.onComplete = {
        WorkflowFinalizer.completeWorkflow(workflow, params);
    }
}
