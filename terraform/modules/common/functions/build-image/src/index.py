import boto3

imagebuilder = boto3.client('imagebuilder')

def lambda_handler(event, context):
    print(event)
    if event['apply_date']:
        imagebuilder.start_image_pipeline_execution(
            imagePipelineArn = event['image_pipeline_arn']
        )