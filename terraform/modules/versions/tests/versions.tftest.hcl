mock_provider "aws" {
  mock_data "aws_eks_cluster_versions" {
    defaults = {
      cluster_versions = [
        { cluster_version = "1.100", version_status = "STANDARD_SUPPORT" },
        { cluster_version = "1.35", version_status = "STANDARD_SUPPORT" },
        { cluster_version = "1.34", version_status = "STANDARD_SUPPORT" },
      ]
    }
  }
  mock_data "aws_rds_engine_version" {
    defaults = { version_actual = "8.0.mysql_aurora.3.10.2" }
  }
}

run "select_versions" {
  command = plan

  assert {
    condition     = output.eks_version == "1.34"
    error_message = "EKS must select the numerically oldest standard-support version."
  }
  assert {
    condition     = data.aws_eks_cluster_versions.standard.version_status == "STANDARD_SUPPORT"
    error_message = "Extended-support EKS versions must be excluded."
  }
  assert {
    condition     = output.aurora_version == "8.0.mysql_aurora.3.10.2"
    error_message = "Aurora must use the resolved version after checking Serverless v2 availability."
  }
  assert {
    condition     = data.aws_rds_engine_version.aurora.parameter_group_family == "aurora-mysql8.0" && data.aws_rds_engine_version.aurora.latest && !data.aws_rds_engine_version.aurora.include_all
    error_message = "Aurora selection must stay on available MySQL 8.0-compatible releases."
  }
  assert {
    condition     = data.aws_rds_orderable_db_instance.aurora.preferred_instance_classes == tolist(["db.serverless"])
    error_message = "Aurora must verify Serverless v2 availability."
  }
}

run "no_standard_versions" {
  command = plan
  override_data {
    target = data.aws_eks_cluster_versions.standard
    values = { cluster_versions = [] }
  }
  expect_failures = [data.aws_eks_cluster_versions.standard]
}
