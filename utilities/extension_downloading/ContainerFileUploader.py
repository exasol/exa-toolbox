import requests
from ReleaseLinkExtractor import ReleaseLinkExtractor


class ContainerFileUploader:
    def __init__(self, file_to_download_name, github_user, repository_name, release_name):
        self.file_to_download_name = file_to_download_name
        self.github_user = github_user
        self.repository_name = repository_name
        self.release_name = release_name

    def upload(self, address, username, password):
        """
        This method uploads the GitHub release into a selected Exasol bucket.
        :param address: address in the format 'http://<host>:<port>/<bucket name>'
        :param username: bucket writing username
        :param password: bucket writing password
        """
        download_url = self.__extract_download_url()
        r_download = requests.get(download_url, stream=True)
        upload_url = self.__build_upload_url(address, username, password)
        requests.put(upload_url, data=r_download.iter_content(10 * 1024))

    def __build_upload_url(self, address, username, password):
        connection_first_part = 'http://'
        split_url = address.split(connection_first_part, 1)
        return connection_first_part + username + ':' + password + '@' + split_url[1] + '/' + self.file_to_download_name

    def __extract_download_url(self):
        github_api_link = self.__construct_github_api_link()
        release_link_extractor = ReleaseLinkExtractor(github_api_link)
        download_url = release_link_extractor.get_link_by_release_name(self.file_to_download_name)
        return download_url

    def __construct_github_api_link(self):
        return "https://api.github.com/repos/" + self.github_user + "/" + self.repository_name + "/releases/" + self.release_name + ""