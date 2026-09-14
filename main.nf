#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Include processes and workflows here
include { run_validate_PipeVal } from './external/pipeline-Nextflow-module/modules/PipeVal/validate/main.nf'

include { generate_standard_filename } from './external/pipeline-Nextflow-module/modules/common/generate_standardized_filename/main.nf'
include { indexFile } from './external/pipeline-Nextflow-module/modules/common/indexFile/main.nf'

// Add this pipeline's custom modules here
include { run_command_Tool } from './module/EXAMPLE_checksum.nf'

// include { tool_name_command_name } from './module/module-name'

// Log info here
log.info """\
        ======================================
        T E M P L A T E - N F  P I P E L I N E
        ======================================
        Boutros Lab

        Current Configuration:
        - pipeline:
            name: ${workflow.manifest.name}
            version: ${workflow.manifest.version}

        - input:
            input a: ${params.variable_name}
            ...

        - output:
            output a: ${params.output_path}
            ...

        - options:
            option a: ${params.option_name}
            ...

        Tools Used:
            tool a: ${params.docker_image_name}

        ------------------------------------
        Starting workflow...
        ------------------------------------
        """
        .stripIndent()

// Establish input channels here
Channel
    .fromList(params.samples_to_process)
    .map { sample ->
        return tuple(sample.id, sample.path, sample.sample_type)
    }
    .set { samplesToProcessChannel }

Channel
    .fromList(params.samples_to_process)
    .map{ it -> [it['path'], indexFile(it['path'])] }
    .flatten()
    .set { files_to_validate_ch }

// These are a few potential channels that can be mixed in

/*
Channel
    .from(
        params.reference,
        params.reference_index,
        params.reference_dict
        )
    .set { reference_ch }

// Decription of input channel
Channel
    .fromPath(params.variable_name)
    .ifEmpty { error "Cannot find: ${params.variable_name}" }
    .set { input_ch_variable_name }

files_to_validate_ch = files_to_validate_ch
    .mix(reference_ch)
    .mix(input_ch_variable_name)
*/

// Main workflow here
workflow {


    base_meta = Channel.value([
        'log_output_dir': params.log_output_dir,
        'output_dir': params.output_dir_base
    ])

    // Validate input files
    run_validate_PipeVal(
        base_meta.combine(files_to_validate_ch)
        )

    // Capture validation results
    run_validate_PipeVal.out.validation_result
        .collectFile(
            name: 'input_validation.txt', newLine: true,
            storeDir: "${params.output_dir_base}/validation"
        )

    // Add pipeline-specific workflow steps here
    run_command_Tool(
        run_validate_PipeVal.out.validated_file
        )

    /*
    tool_name_command_name(
        samplesToProcessChannel,
        input_ch_variable_name
        )
    */

    workflow.onComplete = {
        WorkflowFinalizer.completeWorkflow(workflow, params);
    }
}
