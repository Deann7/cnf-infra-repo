package k8sdeployment

deny[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.securityContext
  msg := "Deployments must have securityContext defined at pod level"
}

deny[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.containers[_].securityContext
  msg := "Deployments must have securityContext defined at container level"
}

deny[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.containers[_].resources
  msg := "Deployments must have resource limits defined"
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits
  msg := sprintf("Container %v must have resource limits defined", [container.name])
}