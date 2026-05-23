variable "key_admin_arns" {
  type        = list(string)
  description = "ARNs of KMS key administrators"
  default     = ["arn:aws:iam::089719647189:user/awesomeone"]
}
