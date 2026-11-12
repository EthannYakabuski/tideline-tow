"""Check served static files and references; this does not execute browser code."""
import argparse, json
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import urlopen

class Links(HTMLParser):
    def __init__(self): super().__init__(); self.urls=[]
    def handle_starttag(self,tag,attrs):
        for key,value in attrs:
            if key in ('src','href') and value and not value.startswith('#'):
                self.urls.append(value)

def main():
    p=argparse.ArgumentParser();p.add_argument('--base',default='http://127.0.0.1:8872/')
    a=p.parse_args();seen={};cache={}
    def check(url):
        if url in seen:return cache[url]
        with urlopen(url,timeout=30) as reply:
            data=reply.read();seen[url]={'status':reply.status,'bytes':len(data),'content_type':reply.headers.get_content_type()}
            assert reply.status==200 and data, url
            cache[url]=data
            return data
    for page in ['', 'review/', 'play/']:
        url=urljoin(a.base,page);data=check(url);parser=Links();parser.feed(data.decode('utf-8'))
        for ref in parser.urls:
            item=urljoin(url,ref)
            if urlparse(item).netloc==urlparse(a.base).netloc:check(item)
    for path in ['build.json','play/index.pck','play/index.wasm']:
        check(urljoin(a.base,path))
    for profile in ['phone','tablet7','tablet10']:
        for name in ['01-home','02-rescue','03-contracts','04-result','05-shipyard','06-journal','07-daily','08-lantern','09-copperdock']:
            check(urljoin(a.base,f'marketing/screenshots/{profile}/{name}.png'))
    result={'status':'PASS','scope':'HTTP static assets only; browser JavaScript/WebGL, interaction and storage NOT TESTED','checked_urls':seen}
    root=Path(__file__).resolve().parents[1];out=root/'build/site-http-check.json'
    out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(f'PASS: {len(seen)} served resources; browser runtime NOT TESTED')

if __name__=='__main__':main()
