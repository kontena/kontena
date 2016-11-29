# Errors

Kontena Master uses the following HTTP error codes:

Error Code | Meaning
---------- | -------
400 | Bad Request -- The request could not be understood by the server due to malformed syntax
401 | Unauthorized -- The request requires a valid access token
403 | Forbidden -- Authenticated user does not have rights to requested resource
404 | Not Found -- Resource not found
500 | Internal Server Error -- The server encountered an unexpected condition which prevented it from fulfilling the request
503 | Service Unavailable -- The server is currently unable to handle the request due to a temporary overloading or maintenance of the server.
