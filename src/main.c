#include <netdb.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>

int main(void) {
	int status;
	struct addrinfo hints;
	struct addrinfo *server_info;

	memset(&hints, 0, sizeof(hints));
	// AI_PASSIVE because we're going to bind instead of using a hostname
	// for getaddrinfo.
	hints.ai_flags = AI_PASSIVE;
	hints.ai_family = AF_UNSPEC; // IPv4 or IPv6
	hints.ai_socktype = SOCK_STREAM;

	// TODO: Listening port should be be configurable and not locked to 8080.
	status = getaddrinfo(NULL, "8080", &hints, &server_info);
	if (status != 0) {
		fprintf(
			stderr,
			"Failed to get server information: %s\n",
			gai_strerror(status)
		);
		return 1;
	}

	// TODO: Do stuff like get a socket and bind to something in the server_info.
	// How do I know which one in the list is valid?

	freeaddrinfo(server_info);

	return 0;
}
