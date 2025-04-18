from django.test import TestCase, Client

class HelloWorldViewTests(TestCase):
    def setUp(self):
        self.client = Client()

    def test_hello_world_response_status(self):
        response = self.client.get('/hello/')  # Adjust the URL if necessary
        self.assertEqual(response.status_code, 200)

    def test_hello_world_response_content(self):
        response = self.client.get('/hello/')  # Adjust the URL if necessary
        self.assertEqual(response.content.decode(), "Hello World, Learn Urdu, checking the automate deployment process")
