import requests
from ReleaseLinkExtractor import ReleaseLinkExtractor


class ContainerFileUploader:
    def __init__(self, release_name, git_hub_api_link):
        self.release_name = release_name
        self.git_hub_api_link = git_hub_api_link

    def upload(self, upload_url):
        """
        This method uploads the GitHub release into a selected Exasol bucket.
        :param upload_url: URL for uploading a file in format http://w:<writing password>@<host>:<port>/<bucket name>/<file name>
        """
        download_url = self.__extract_download_url()
        r_download=requests.get(download_url,stream=True)
        requests.put(upload_url, data=r_download.iter_content(10*1024))

    def __extract_download_url(self):
        release_link_extractor = ReleaseLinkExtractor(self.git_hub_api_link)
        download_url = release_link_extractor.get_link_by_release_name(self.release_name)
        return download_url
