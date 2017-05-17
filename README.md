# AzureArmWebExample
A set of automation scripts that shows how to automate a simple web application



## Plan of the demonstration

1. Use Azure CLI to create a VNET
2. Create an ARM template with a VM Scaleset or multiple VM's. Connect the VM's to the VNET that you created in the first step.
3. Use Azure Automation and DSC to configure the Virtual Machines with Nginx or Apache. Install a demopage or install Wordpress
4. Use and external loadbalancer to loadbalance port 80 (SSL is optional).
5. Create a bash or PowerShell script that interacts with the Azure cli or Azure PowerShell to automate the deployment of the template.