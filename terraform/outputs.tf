output "echo-frontend-url-command" {
  value = "echo http://$(kubectl get ing -n cloudacademy frontend -o jsonpath='{.spec.rules[0].host}')"
}
