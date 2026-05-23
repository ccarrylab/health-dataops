## Project Structure

See folder structure at top of this file.

## Security

- All S3 buckets encrypted with KMS
- Compute in private subnets (no public IP)
- GitHub OIDC for CI/CD (no AWS access keys)
- IAM roles follow least privilege
- CloudTrail + CloudWatch for audit

HIPAA-oriented, but actual compliance requires BAAs and organizational controls.

## Costs

### Default Mode (Production Demo)
- MWAA: $120/month
- EMR cluster: $60/day
- NAT Gateway: $32/month
- **Total**: ~$220/month

### Cost-Optimized Mode (Portfolio)
- MWAA (1-2 workers): $40/month
- EMR Serverless: $5/job (~$20/month)
- VPC endpoints only: $7/month
- **Total**: ~$67/month

## Destroy When Done
```bash
cd infra/environments/dev
terraform destroy
aws s3 rm s3://health-dataops-terraform-state-$ACCOUNT --recursive
aws s3api delete-bucket --bucket health-dataops-terraform-state-$ACCOUNT
```

Set a calendar reminder. NAT Gateway and MWAA will burn money if you forget.

## Credits

Built as a portfolio project. No external templates copied.

## Contact

Open to feedback. If you're hiring for a DataOps role, hit me up.

---

Built with ❤️ for health tech, not for tutorials. Cost-optimized for job hunting.
