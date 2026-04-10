output "alb_dns_name" {
  description = "URL del Load Balancer — copiar para el curl de prueba y para K6"
  value       = aws_lb.app_alb.dns_name
}

output "asg_name" {
  description = "Nombre del ASG para monitorear"
  value       = aws_autoscaling_group.app_asg.name
}

output "k6_command" {
  description = "Comando listo para correr el test de carga"
  value       = "k6 run -e BASE_URL=http://${aws_lb.app_alb.dns_name} ../k6/test_escalabilidad.js"
}
