import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
import getpass
import sys
import json
import csv
import argparse


def chkp_api_login(server, port, username, password, domain=''):
    if domain == '':
        payload = {'user':username, 'password' : password}
    else:
        payload = {'user':username, 'password' : password, 'domain': domain}
    return chkp_api_call(server, port, 'login', payload, '')


def chkp_api_logout(server, port, sid):
    return chkp_api_call(server, port, 'logout', {}, sid)


def chkp_api_call(server, port, command, json_payload, sid):
    url = 'https://' + server + ':' + str(port) + '/web_api/' + command
    if sid == '':
        request_headers = {'Content-Type': 'application/json'}
    else:
        request_headers = {
            'Content-Type': 'application/json', 
            'X-chkp-sid': sid
        }
    request = requests.post(
            url,
            data=json.dumps(json_payload), 
            headers=request_headers,
            verify=False
        )
    return request


def mds_domain_menu(all_mds_domains):
    domain_name = None

    while domain_name not in all_mds_domains:
        i = 1
        for domain in all_mds_domains:
            print('{}. {}'.format(i, domain))
            i += 1

        choice = input('Choose a domain: ')
        try:
            choice = int(choice) - 1
            domain_name = all_mds_domains[choice]
        except:
            domain_name = choice

    return domain_name


def add_hosts_from_csv(filepath, server, port, sid='', domain_sid=''):
    with open(filepath, 'r') as csv_file:
        csv_row_reader = csv.reader(csv_file)

        is_first_row = True
        for row in csv_row_reader:
            # Skip first row in CSV
            if is_first_row:
                is_first_row = False
                continue

            # Convert row to JSON payload
            payload = {}
            object_name = ''
            if row != []:
                object_name = 'h_' + str(row[0])
                payload = {'name': object_name, 'ip-address': str(row[0])}
            else:
                continue
            
            # Depending on sid provided we will make API call to MDS or CMA
            print('INFO: Attempting to create host object \'{}\''.format(object_name))
            api_call = None
            if sid != '':
                api_call = chkp_api_call(server, port, 'add-host', payload, sid)
            elif domain_sid != '':
                api_call = chkp_api_call(server, port, 'add-host', payload, domain_sid)

            # Report status of API call
            if api_call != None and api_call.status_code != 200:
                print('ERROR: Unable to create host object \'{}\''.format(object_name))
                print('INFO:', api_call.json()['message'])
                print('WARNINGS:', api_call.json()['warnings'])
                print('ERRORS:', api_call.json()['errors'])
            else:
                print('INFO: Created host object \'{}\''.format(object_name))


def main():
    # Get Checkpoint Management Server Creds from User
    parser = argparse.ArgumentParser(description='Bulk import host objects into Checkpoint Management SMS/MDS')
    parser.add_argument('-s', '--server_ip', dest='server_ip', help='')
    parser.add_argument('-d', '--domain', dest='mds_domain', help='')
    parser.add_argument('-P', '--api_port', dest='api_port', help='')
    parser.add_argument('-u', '--username', dest='api_user', help='')
    parser.add_argument('-p', '--password', dest='api_pass', help='')
    args = parser.parse_args()
    
    if args.server_ip == None:
        api_server = input("Enter server IP address or hostname: ")
    else:
        api_server = args.server_ip

    if args.api_port == None:
        api_port = input('Enter server API port [0-65535]: ')
    else:
        api_port = args.api_port

    if args.api_user == None:
        username = input("Enter username: ")
    else:
        username = args.api_user

    if args.api_pass == None:
        if sys.stdin.isatty():
            password = getpass.getpass("Enter password: ")
        else:
            print("Attention! Your password will be shown on the screen!")
            password = input("Enter password: ")
    else:
        password = args.api_pass

    # Login and get Session ID
    print('INFO: Attempting to login to Management API...')
    sid = chkp_api_login(api_server, api_port, username, password).json()['sid']
    if sid == '':
        print('ERROR: Unable to create session!')
        exit(1)
    else:
        print('INFO: Login successful! Session ID = \'{}\''.format(sid))

    # Get all domain names
    domains = []
    payload = {'limit': 500, 'offset': 0, 'details-level': 'standard'}
    api_call = chkp_api_call(api_server, api_port, 'show-domains', payload, sid)

    # Check if mgmt is MDS
    is_mds = False
    if api_call.status_code == 200:
        is_mds = True
        for domain in api_call.json()['objects']:
            domains.append(domain['name'])
    else: 
        print('WARN: Unable to get domains. Possible running commands on a SMS.')

    if is_mds:
        is_standby_domain = False
        domain_sid = ''

        if args.mds_domain == None:
            # List all domains
            domain = mds_domain_menu(domains)
        else:
            domain = args.mds_domain

        # Connect to domain
        print('INFO: Attempting to login to domain \'{}\'...'.format(domain))
        domain_login = chkp_api_login(api_server, api_port, username, password, domain)
        domain_sid = domain_login.json()['sid']
        if domain_sid == '':
            print('ERROR: Unable to create session!')
            exit(1)
        else:
            print('INFO: Login successful! Domain Session ID = \'{}\''.format(domain_sid))
            # Check if connected domain CMA is standby
            if 'standby' in domain_login.json().keys():
                print('ERROR: Connected to standby member of domain!')
                is_standby_domain = True

        # Import CSV list of host objects
        if is_standby_domain:
            print('INFO: Skipping host object import due to connection to standby domain.')
        else:
            # TODO: Get all current objects in domain
            # TODO: Compare existing objects to objects to be imported
            print('INFO: Reading hosts from hosts.csv')
            add_hosts_from_csv('hosts.csv', api_server, api_port, domain_sid=domain_sid)

            # Publish changes made
            print('INFO: Publishing changes')
            api_call = chkp_api_call(api_server, api_port, 'publish', {}, domain_sid)
            if api_call.status_code != 200:
                print('ERROR: Failed to publish session!')
            else:
                print('INFO: Session published!')
        
        # Logout of domain API session
        logout = chkp_api_logout(api_server, api_port, domain_sid)
        if logout.status_code == 200:
            print('INFO: Logout of domain successful!')

    # Logout of mgmt API session
    logout = chkp_api_logout(api_server, api_port, sid)
    if logout.status_code == 200:
        print('INFO: Logout successful!')


if __name__ == '__main__':
    main()
