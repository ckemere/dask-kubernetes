from jupyter_core.paths import jupyter_data_dir
import subprocess
import os
import errno
import stat

c = get_config()
c.NotebookApp.password = u'sha1:e6888af5df44:e161f2e90fb7b03c52e979dfcf18f10353caef22'
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.token = ''
c.NotebookApp.open_browser = False
c.NotebookApp.port = 8888

# Generate a self-signed certificate
dir_name = jupyter_data_dir()
pem_file = os.path.join(dir_name, 'notebook.pem')
try:
  os.makedirs(dir_name)
except OSError as exc:  # Python >2.5
  if exc.errno == errno.EEXIST and os.path.isdir(dir_name):
    pass
  else:
    raise
# Generate a certificate if one doesn't exist on disk
subprocess.check_call(['openssl', 'req', '-new',
		   '-newkey', 'rsa:2048',
		   '-days', '365',
		   '-nodes', '-x509',
		   '-subj', '/C=XX/ST=XX/L=XX/O=generated/CN=generated',
		   '-keyout', pem_file,
		   '-out', pem_file])
# Restrict access to the file
os.chmod(pem_file, stat.S_IRUSR | stat.S_IWUSR)
c.NotebookApp.certfile = pem_file

