# Auth0 Tenant Security Hands-on Workshop

Both Okta and Auth0 have many features and functions that protect our customers from nefarious activities. However, there is no single, overarching story through which we can walk customers through to help them identity, protect, and mitigate these common security risks.

This Auth0 reference implementation uses Terraform to configure an Auth0 tenant with a solid base of security features enabled to help protect against common password attacks, such as:
- [Credential Stuffing Attacks](https://owasp.org/www-community/attacks/Credential_stuffing)
- [Brute Force Attacks](https://owasp.org/www-community/attacks/Brute_force_attack)
- [Dictionary Attacks](https://owasp.org/www-project-automated-threats-to-web-applications/assets/oats/EN/OAT-007_Credential_Cracking) - a hybrid of brute force
- [Password Spraying Attacks](https://owasp.org/www-community/attacks/Password_Spraying_Attack) - a hybrid of brute force
- [Manipulator-In-The-Middle Attacks](https://owasp.org/www-community/attacks/Manipulator-in-the-middle_attack)
- [Phishing Attacks](https://owasp.org/www-community/attacks/Content_Spoofing) - also called content spoofing

To test that these Auth0 protections work, Terraform will also start a Docker container running an Express.js app locally, which be used to test the login screen security.

## 🚀 Getting Started

### Prerequisites

There are a few things you will need setup on your computer before getting started:

1. [Free Auth0 Account](https://auth0.com/signup)
1. [Docker](https://www.docker.com/get-started). You can check that Docker is installed properly by running `docker info` in your console. 
1. [Terraform](https://learn.hashicorp.com/terraform/getting-started/install). You can check that Terraform is installed properly by running `terraform -v` in your console. 

> :warning: Please make sure these are installed on your machine before continuing. 

In order for Terraform to be able to create Clients and APIs in Auth0 automagically (yes, it's a word), you'll need to manually create an Auth0 Machine-to-Machine Application that allows Terraform to communicate with Auth0. 
1. Navigate to your [Auth0 Dashboard](https://manage.auth0.com/dashboard) -> Applications -> Create Application.
1. Name your new application `Terraform Auth0 Provider`. 
1. Select `Machine To Machine Applications` and Create.
1. Under settings, save the `domain`, `client_id`, and `client_secret` for later.

### Running locally

In order for the Terraform automation to run smoothly, a few local environment files will need to be created.

- First, clone https://github.com/tylernix/auth0-tenant-security-hands-on-workshop.git.
- Create a `local.tfvars` in your root project directory that defines the necessary Auth0 configuration values as follows:

```bash
# The url of your Auth0 tenant domain (without the https://).
auth0_domain = "YOUR_AUTH0_DOMAIN.auth0.com"
# Your Auth0 Terraform Auth0 Provider M2M Client ID
auth0_client_id = "YOUR_AUTH0_CLIENT_ID"
# Your Auth0 Terraform Auth0 Provider M2M Client Secret
auth0_client_secret = "YOUR_AUTH0_CLIENT_SECRET"
# The password to be used when create users
auth0_admin_user_password = "YOUR_FAVORITE_TERRIBLE_PASSWORD"
```

### Terraform

Once you have your local variables set up, you can run terraform. 

- First, run `terraform init` in your console inside the root of your project. This command gets your Terraform environment ready to go, installing any plugins and providers required for your configuration.
- Run `terraform apply -var-file="local.tfvars"`. Type `yes` and hit enter. Terraform will now take care of the hard work of creating all the resources necessary to get this demo up and running in your Auth0 tenant. Most Terraform providers are [idempotent](https://en.wikipedia.org/wiki/Idempotence), meaning running `terraform apply` doesn't have any additional effect once the infrastructure is set up.

Terraform will create:
1. One client in Auth0 called `Terraform Secure Express`, with the JWT signing algorithm set to the most secure `RS256` method.
1. A database in Auth0 to store users called `terraform-express-user-db`, disallowing the [10,000 most commonly used passwords](https://auth0.com/docs/authenticate/database-connections/password-options#password-dictionary) and [adding user attributes to the deny list](https://auth0.com/docs/secure/security-guidance/data-security/denylist) if data privacy is a concern.
1. Configure the Auth0 tenant to disallow all current connections from being enabled on a new client when a new client is created.
1. Three users in Auth0 called `admin@example.com`, `bruteforce-test@example.com`, `leak-test@example.com`.
1. Enable [Adaptive Multi-factor Authentication](https://auth0.com/docs/secure/multi-factor-authentication/adaptive-mfa) with `Email` and `One Time Passcode (OTP)` as allowed MFA factors.
1. An API resource server in Auth0 called `Terraform Auth0 Resource Server`.
1. Configure `Suspicious IP Throttling`, `Brute Force Protection`, and `Breached Password Detection`. 
1. One Docker image for the `Terraform Secure Express` app.
1. One Docker container running on **http://localhost:3000**, passing in the configuration settings from the recently created Auth0 client.

### Lab
(After each step, add the configuration resource to `main.tf` and run `terraform apply -var-file="local.tfvars"`)

1. Set tenant to not allow all current connections to be enabled when a new client is created. We want to be in control of this when automating apps/connections by only giving least access.
1. Create client in terraform. Make sure to set jwt algorithm to RS256. Giving reasoning around why.
1. Create connection. Enable a secure password policy and password dictionary, which does not allow passwords upon user signup that are part of the 10,000 worst passwords list + `Password1!` since it meets the requirements of good and isn’t contained in the 10,000 list. 
    - > Side note: If you want to protect user’s privacy by not collecting data you do not need, you can add user attributes to the deny list so they don’t show up in tokens/logs (name, given_name, family_name, phone_number, etc)
1. Enable One-Time-Passcode MFA + Email. Explain what is Adaptive MFA. Explain the importance of having two MFA factors in case one gets lost/stolen/compromised. 
    - > Bonus points: only enable phishing-resistant Multi-Factor Authentication factors. This can’t be done via terraform (yet).
1. Enable Suspicious IP throttling attack protection. Auth0 counts and allows login and signup attempts separately. IP addresses suspended from further login attempts can still try to sign up. IP addresses suspended from further signup attempts can still try to log in.
1. Enable brute-force attack protection.  Inspect the velocity of login attempts from an IP for a particular account and block if exceeds a max_attempt threshold. 
1. Enable breached password detection attack protection. Blocks the login attempt if a breached password is used that appears in lists of breached passwords released on the dark web. Explain what is credential guard and how to enable it on tenant.
1. Enable bot detection manually via the dashboard. Can’t be done via terraform (yet), apparently Q2/2022.
1. TODO:  Stream tenant logs to continuously review Attack Protection events. Explain how to inspect logs to identify common incidents and how to respond. 
1. > Bonus points: Get all of the Auth0 dashboard administrators to start using MFA for their account. Can’t be done via terraform (yet).

### Testing

After running these commands, go to [http://localhost:3000](http://localhost:3000) to see the running application.

1. Confirm you can’t sign up with an account `test@example.com` using the password `Password1!`  
1. Confirm `leak-test@example.com` email + `Paaf213XXYYZZ` password shows breached password error upon login. This password is intentionally put here, since it is already exposed in a data breach. This is the same password example used in the [Breached Password Detection](https://auth0.com/docs/secure/attack-protection/breached-password-detection#verify-detection-configuration) documentation.
1. Confirm `bruteforce-test@exmaple.com email` + any 3 random passwords shows suspicious login activity error. Account needs to be unblocked manually from the dashboard. 
1. Confirm 2 more random email+password combinations show suspicious IP activity error.
1. TODO: Set MFA to always and confirm it works upon next login.
1. TODO: Confirm tenant logs are streamed to data provider. 
1. TODO: Act upton tenant logs to stop various incidents from happening in the future. 

### Clean up

When you are done with the demo, you can run `terraform destroy -var-file="local.tfvars"` to delete everything configured in this demo from Auth0 and stop the docker containers running locally.

## ✅ TODO
- [ ] Optimize `Dockerfile` so that the build is less than 1.02 GB
- [ ] Update documentation into a tutorial to include an initial terraform file with basic configuration, then slowly add terraform resources by following a tutorial, till the final terraform file is achieved. Basically split the terraform script into chunks so that teaching can be interspersed with adding terraform configurations.
- [ ] Set up [Auth0 tenant log streaming](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/log_stream) via Terraform to a data provider in order to analyze the logs and create various [incident response scenarios](https://auth0.com/docs/secure/security-guidance/incident-response-using-logs)
- [ ] Finish documentation for Testing section to include instructions on how to test MFA and tenant log stream + incident response.
- [] Figure out how this lab could be run on a remote machine (something like [Github codespaces](https://github.com/features/codespaces) or [Codesandbox](https://codesandbox.io/) ) to make it easy for workshop attendees to to get started without having to download anything locally to their machine. 
- [ ] This tutorial only focuses on Auth0 tenant security configurations. Another deep-dive into app level security such as [Preventing CSRF attacks by using the state parameter](https://auth0.com/docs/secure/attack-protection/state-parameters) or properly storing user data between [Auth0 data store and external database](https://auth0.com/docs/secure/security-guidance/data-security/user-data-storage#external-database-vs-auth0-data-store) or talking about [token best practices](https://auth0.com/docs/secure/tokens/token-best-practices) or [properly storing tokens](https://auth0.com/docs/secure/security-guidance/data-security/token-storage) (this can get complicated since it varies based on public vs confidential clients)
