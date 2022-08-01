terraform {
  backend "http" {
    address        = "https://github.com/api/v4/projects/36387210/terraform/state/tfstat"
    lock_address   = "https://github.com/api/v4/projects/36387210/terraform/state/tfstat/lock"
    unlock_address = "https://github.com/api/v4/projects/36387210/terraform/state/tfstat/lock"
    username       = "Shankar Pinnelli"
    password       = "glpat-YCRnXZM_D75Yq-S2zA9h"
    # password      = not in configuration
    lock_method    = "POST"
    unlock_method  = "DELETE"    
  }
}
