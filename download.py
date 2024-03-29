#!/usr/bin/env python3
import os
import json
import lzma
import hashlib
import argparse
import requests
import tempfile

MASTER_MANIFEST = "https://raw.githubusercontent.com/commaai/openpilot/master/system/hardware/tici/agnos.json"
RELEASE_MANIFEST = "https://raw.githubusercontent.com/commaai/openpilot/release3/system/hardware/tici/agnos.json"

def download_and_decompress(url, hash, filename):

  # check if already downloaded
  if os.path.isfile(filename):
    sha256 = hashlib.sha256()
    with open(filename, 'rb') as f:
      for chunk in iter(lambda: f.read(1024*1024), b''):
        sha256.update(chunk)

    if sha256.hexdigest().lower() == hash.lower():
      print("already downloaded ", filename)
      return 0

  size_counter = 0
  dot_counter = 0
  decompressor = lzma.LZMADecompressor(format=lzma.FORMAT_AUTO)
  sha256 = hashlib.sha256()
  with requests.get(url, stream=True, headers={'Accept-Encoding': None}) as download_stream:
    download_stream.raise_for_status()
    size = int(download_stream.headers.get("Content-Length"))
    with open(filename, 'wb') as f:
      for chunk in download_stream.iter_content(chunk_size=1024*1024):
        decompressed_chunk = decompressor.decompress(chunk)
        sha256.update(decompressed_chunk)
        f.write(decompressed_chunk)
        size_counter += len(chunk)

        # Every MB
        if size_counter//(1024*1024) > dot_counter:
          print(f"Downloading '{filename}': {(size_counter*100)//size}%", end='\r')
          dot_counter += 1
  print(f"Downloading '{filename}': 100%")
  assert(sha256.hexdigest().lower() == hash.lower())

def load_manifest(url):
  r = requests.get(url)
  r.raise_for_status()
  return json.loads(r.content.decode())


if __name__ == "__main__":
  parser = argparse.ArgumentParser(description='Download AGNOS')
  parser.add_argument('--master', action='store_true',
                      help='Download AGNOS version used in the master branch')
  parser.add_argument('--manifest', nargs='?',
                      help='Download AGNOS from the manifest at this URL')

  args = parser.parse_args()

  manifest = RELEASE_MANIFEST
  if args.manifest is not None:
    manifest = args.manifest
  elif args.master:
    manifest = MASTER_MANIFEST

  update = load_manifest(manifest)
  for partition in update:
    download_and_decompress(partition['url'], partition['hash'], f"{partition['name']}.img")

  with open(f"reset_userdata.img", "wb") as fh:
    reset_bytes ="COMMA_RESET".encode("utf-8")
    remaining_length = 28 - len(reset_bytes)
    null_bytes = b"\x00" * remaining_length
    fh.write(reset_bytes + null_bytes)
