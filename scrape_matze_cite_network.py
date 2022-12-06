#!/usr/bin/env python3
import os
import re
import tqdm
import time
import requests
import json
from tika import parser
from bs4 import BeautifulSoup

# ensure folder structure is set up
if "data" not in os.listdir():
    os.mkdir("data")

# http headers
headers = {
# "Accept": "text/plain",
# "Accept-Charset": "utf-8",
# "Accept-Encoding": "gzip, deflate",
"Accept-Language": "en-US",
# "Cache-Control": "max-age=0",
"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:25.0) Gecko/20100101 Firefox/25.0",
}

# set path to pdfs folder
data_path = "data/"
matze_url = "https://scholar.google.com/citations?user=qmdoiikAAAAJ&hl=en&oi=sra"

# scrape Google scholar links to papers that cite Matze's papers
response = requests.get(matze_url, allow_redirects = True, headers = headers)
soup = BeautifulSoup(response.content, "html.parser")
paper_cites = soup.find_all("a", {"class": "gsc_a_ac gs_ibl"}, href = True)
cites_links = []
for a in paper_cites:
    cites_links.append(re.sub("&oe=ASCII", "", a['href']))

# save for later
with open("cites_links.json", 'w') as f:
    json.dump(cites_links, f)

# scraping links to pdfs (and web versions of articles)
# 1st page: https://scholar.google.com/scholar?cites=17517526121420329348&as_sdt=8005&sciodt=0,7&hl=en
# 2nd page: https://scholar.google.com/scholar?start=10&hl=en&as_sdt=8005&sciodt=0,7&cites=17517526121420329348&scipsc=
# my edit: https://scholar.google.com/scholar?start=10&cites=17517526121420329348&as_sdt=8005&sciodt=0,7&hl=en
print("Scraping links...")
paper_urls = []
for url in cites_links:
    if url != "":
        print(f"Scraping links from {url}...")
        found_end = False
        i = 0
        while(not found_end):
            # iterate through results pages (step size = 10)
            url_edit = re.sub("(cites=.*)", ("start=" + str(i) + "&\\1"), url)
            p = requests.get(url_edit, allow_redirects = True, headers = headers)
            soup = BeautifulSoup(p.content, "html.parser")
            # get links to pdfs
            link_div = soup.find_all("div", {"class": "gs_or_ggsm"})
            # check if there are still papers listed for the given results page
            if len(link_div) == 0:
                found_end = True
            else:
                for div in link_div:
                    link = div.find('a', href = True)['href']
                    paper_urls.append(link)
                i = i + 10
            time.sleep(1)

# save links for later
with open("paper_links.json", 'w') as f:
    json.dump(paper_urls, f)

print("Scraping links done.")

# pull pdfs (and web versions of articles)
print("Pulling PDF files...")
i = 0
for url in paper_urls:
    if(url != ""):
        file = requests.get(url, allow_redirects = True, headers = headers)
        if "pdf" in url:
            # file_name = "paper" + str(i) + ".pdf"
            file_name = str(i) + "_" + re.sub("http[s]{0,1}://(www.){0,1}(.+?)\\..*/", "\\2_", url) + ".pdf" # removes the "https://" part etc.
        else:
            # file_name = "paper" + str(i) + ".html"
            file_name = str(i) + "_" + re.sub("http[s]{0,1}://(www.){0,1}(.+?)\\..*/", "\\2_", url) + ".html" # removes the "https://" part etc.
        print(f"Pulling {file_name}.")
        try:
            with open(data_path + file_name, 'wb') as f:
                f.write(file.content)
                time.sleep(1)
            i = i + 1
        except AttributeError:
            print("Invalid file name.")
    else:
        print("Empty URL encountered.")

print("Pulling PDFs done.")
