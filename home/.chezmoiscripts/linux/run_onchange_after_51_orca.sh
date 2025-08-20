if [[ ! -d ~/.orca ]]; then
  # init orca:
  echo "setting up for orca"
  orca config --answer-yes --username $USER
fi