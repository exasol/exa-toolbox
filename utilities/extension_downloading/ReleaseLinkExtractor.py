import requests


class ReleaseLinkExtractor:
    def __init__(self, repository_api_link):
        """
        Create a new instance of ReleaseLinkExtractor class.
        :param repository_api_link: Link to the GitHub API page with the latest release.
        """
        self.repository_api_link = repository_api_link

    def get_link_by_release_name(self, file_to_download_name):
        """
        This method extracts a link from the GitHub API page searching by a release name.
        :param file_to_download_name: the name of the file
        :return: a link in a string format
        """
        response = requests.get(self.repository_api_link)
        json_release_page = response.json()
        list_of_available_releases = json_release_page["assets"]
        result_link = self.__find_link(list_of_available_releases, file_to_download_name)
        if result_link is not None:
            return result_link
        else:
            raise ValueError(
                'Release with the name ' + file_to_download_name + ' was not found. Please check the name or select another release')

    def __find_link(self, list_of_available_releases, release_name):
        for release in list_of_available_releases:
            if release_name in release["name"]:
                return release["browser_download_url"]