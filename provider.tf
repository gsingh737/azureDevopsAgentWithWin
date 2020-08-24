provider "azurerm" {
  version = "=2.18.0"
  features {}
}

terraform {
    backend "azurerm" {
        # storage_account_name = "<STORAGE ACCOUNT NAME>"
        # container_name = "<CONTAINER NAME>"
        # key = "terraform-devops-agent.tfstate"
        # sas_token = "?sv=2019-10-10&ss=b&srt=sco&sp=rwdlacx&se=2020-07-30T04:30:13Z&st=2020-05-22T20:30:13Z&spr=https&sig=Hgi3PYRTs3EKhbqUzbG9XazEAW4TW0FWAl7m7QhII4I%3D"
    }
}