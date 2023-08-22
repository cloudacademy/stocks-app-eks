output "echo-frontend-url-command" {
  value = "echo http://$(kubectl get ing -n cloudacademy frontend -o jsonpath='{.spec.rules[0].host}')"
}

output "api_test_wait_command" {
  value       = "until curl -Is --max-time 5 http://$(kubectl get ing -n cloudacademy api -o jsonpath='{.spec.rules[0].host}')/api/stocks/csv | grep 'HTTP/1.1 200'; do echo preparing...; sleep 5; done; echo; echo -e 'Ready...'"
  description = "Test command - tests readiness of the web app"
}

output "app_test_wait_command" {
  value       = "until curl -Is --max-time 5 http://$(kubectl get ing -n cloudacademy frontend -o jsonpath='{.spec.rules[0].host}')/ | grep 'HTTP/1.1 200'; do echo preparing...; sleep 5; done; echo; echo -e 'Ready...'"
  description = "Test command - tests readiness of the web app"
}
