#!/usr/bin/env python3
import os
import re
import tqdm
import time
import json
from tika import parser

# create directory
if "raw_texts" not in os.listdir():
    os.mkdir("raw_texts")

# set path to pdfs folder
pdfs_path = "data/"
txt_path = "raw_texts/"

# extract raw text from pdf files
print("Getting text from PDFs.")
list_pdfs = os.listdir(pdfs_path)
for file_name in list_pdfs:
    # check whether file is pdf
    if file_name[-3:] == "pdf":
        print(f"Extracting raw text from {file_name}.")
        path_to_pdf = pdfs_path + file_name
        # extract raw text from pdf using tika
        raw = parser.from_file(path_to_pdf)
        # save raw text as .txt for later parsing
        with open((txt_path + file_name[:-4] + ".txt"), "w") as f:
            f.write(raw["content"])

print("Finished extracting raw text.")
