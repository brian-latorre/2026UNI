import urllib.request, json, re

with open(r'.env', 'r') as f:
    env = f.read()
    
token = re.search(r'GITHUB_TOKEN=(.+)', env).group(1).strip()
repo = re.search(r'GITHUB_REPO=(.+)', env).group(1).strip()

req = urllib.request.Request(f'https://api.github.com/repos/{repo}/actions/runs?per_page=1')
req.add_header('Authorization', f'token {token}')
req.add_header('Accept', 'application/vnd.github.v3+json')
res = urllib.request.urlopen(req)
data = json.loads(res.read())

if not data.get('workflow_runs'):
    print('No runs found')
else:
    run = data['workflow_runs'][0]
    print(f"Run ID: {run['id']}, Status: {run['status']}, Conclusion: {run['conclusion']}")
    
    jobs_req = urllib.request.Request(run['jobs_url'])
    jobs_req.add_header('Authorization', f'token {token}')
    jobs_req.add_header('Accept', 'application/vnd.github.v3+json')
    jobs_res = urllib.request.urlopen(jobs_req)
    jobs_data = json.loads(jobs_res.read())
    
    for job in jobs_data['jobs']:
        print(f"Job: {job['name']}, Conclusion: {job['conclusion']}")
        for step in job['steps']:
            if step['conclusion'] == 'failure':
                print(f"  Step failed: {step['name']}")
                
                # Fetch logs for the failed job
                try:
                    logs_req = urllib.request.Request(f"https://api.github.com/repos/{repo}/actions/jobs/{job['id']}/logs")
                    logs_req.add_header('Authorization', f'token {token}')
                    logs_res = urllib.request.urlopen(logs_req)
                    logs_content = logs_res.read().decode('utf-8')
                    # Just print the last 20 lines of the log
                    lines = logs_content.splitlines()
                    print("\n--- Last 20 lines of failed job log ---")
                    for line in lines[-20:]:
                        print(line)
                    print("---------------------------------------")
                except Exception as e:
                    print(f"Could not fetch logs: {e}")
