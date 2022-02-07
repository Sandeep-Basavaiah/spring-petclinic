/*
 For demo purposes we deploy a small app using the kubernetes_ingress ressource
 and a fargate profile
*/


resource "aws_iam_role_policy_attachment" "AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_pod_execution_role.name
}

resource "aws_iam_role" "fargate_pod_execution_role" {
  name                  = "${var.name}-eks-fargate-pod-execution-role"
  force_detach_policies = true

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "eks.amazonaws.com",
          "eks-fargate-pods.amazonaws.com"
          ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_eks_fargate_profile" "main" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "fp-default"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution_role.arn
  subnet_ids             = var.private_subnets.*.id

  selector {
    namespace = "default"
  }

  selector {
    namespace = "spring-petclinic"
  }

  timeouts {
    create = "30m"
    delete = "60m"
  }
}

resource "kubernetes_namespace" "example" {
  metadata {
    labels = {
      app = "spetclinic"
    }

    name = "spring-petclinic"
  }
}

resource "kubernetes_secret" "docker_pull_secret" {
  metadata {
    name = "kubernetes_secret"
    namespace = "${kubernetes_namespace.example.metadata.0.name}"
  }

  data {
    ".dockerconfigjson" = "${file("${path.module}/docker-registry.json")}"
    # ".dockercfg" = "${file("${path.module}/docker-registry.json")}"
  }

  type = "kubernetes.io/dockerconfigjson"
  # type = "kubernetes.io/dockercfg"
}

# resource "kubernetes_secret" "docker_pull_secret" {
#   metadata {
#     name = "basic-auth"
#   }

#   data = {
#     username = "cloudablaze"
#     password = "Shreyank@09"
#   }

#   type = "kubernetes.io/basic-auth"
# }

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "deployment-spring-petclinic"
    namespace = "spring-petclinic"
    labels    = {
      app = "spetclinic"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "spetclinic"
      }
    }

    template {
      metadata {
        labels = {
          app = "spetclinic"
        }
      }

      spec {
        image_pull_secrets {
          name = "${kubernetes_secret.docker_pull_secret.metadata.0.name}"
        }
        container {
          # image = "alexwhen/docker-2048"
          image = "registry.gitlab.com/cloudablaze/spring-petclinic"
          name  = "spetclinic"

          port {
            container_port = 8080
          }
        }
      }
    }
  }

  depends_on = [aws_eks_fargate_profile.main]
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "service-spetclinic"
    namespace = "spring-petclinic"
  }
  spec {
    selector = {
      app = "spetclinic"
    }

    port {
      # port        = 80
      # target_port = 80
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    type = "NodePort"
  }

  depends_on = [kubernetes_deployment.app]
}

resource "kubernetes_ingress" "app" {
  metadata {
    name      = "spetclinic-ingress"
    namespace = "spring-petclinic"
    annotations = {
      "kubernetes.io/ingress.class"           = "alb"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      # "external-dns.alpha.kubernetes.io/hostname": "pets.spetclinic.com"
    }
    labels = {
        "app" = "spetclinic-ingress"
    }
  }

  spec {
    rule {
      http {
        path {
          path = "/*"
          backend {
            service_name = "service-spetclinic"
            service_port = 80
            # service_port = 8080
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.app]
}