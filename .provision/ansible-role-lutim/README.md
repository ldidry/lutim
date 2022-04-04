Ansible-Role-lutim
=========
This role installs the and configures lutim on Debian/Ubuntu servers with nginx web server configuration.

Role Variables
-------------- 
| Variable name | Value | Description |
| ------------- | ----- | ----------- |
| `app_dir` | /var/www/lutim | Set the application directory for the best practice |
| `lutim_owner` | www-data | Set the application user for the best practice |
| `lutim_group` | www-data | Set the application group for the best practice |
| `_contact` | contact.example.com | Contact option (mandatory), where you have to put some way for the users to contact you. |
| `_secrets` | ffyg7kbkjba | Secrets option (mandotory), which is array of random string. Used by Mojolicious for encrypting session cookies |
| `_project_version` | master | We can chose the project version either Master branch, Dev branch or tag based |
| `_server_name` | IP address (or) CNAME/FQDN | Mention the Server Name for the Nginx configurations |

Sample example of use in a playbook
--------------

The following code has been tested with Ubuntu 20.04

```yaml
 
- name: "install lutim"
  hosts: enter your hosts file
  become: yes
  role:
    - ansible-role-lutim
  vars:
    lutim_owner: "www-data"
    lutim_group: "www-data"
    contact: "contact.example.com"
    secrets: "yigavlvlivwe"
    app_dir: "/var/www/lutim"
    project_version: "master"
    servername: "IP address (or) CNAME/FQDN"
```   

Contributing
------------
Don’t hesitate to create a pull request









