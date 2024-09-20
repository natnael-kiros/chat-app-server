# Chat App Server

This is the **server-side** component of the chat application, built using **Dart**. It handles requests, authentication, real-time messaging, and stores messages using SQLite. The server works in conjunction with the Flutter-based client-side app, which you can find [here](https://github.com/natnael-kiros/chat-app).

## Features

- **Authentication:** Handles user authentication (sign up and log in).
- **Real-Time Chat:** Supports instant messaging between users and group chats.
- **Message Storage:** Messages are stored in an SQLite database with timestamps.
- **Broadcast Messages:** Enables one-way communication for updates.
- **Group Chats:** Manages group creation and messaging.

## Setup and Installation

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart) installed on your machine.
- An SQLite database for message storage.

### Steps

1. **Clone the repository:**

   git clone https://github.com/natnael-kiros/chat-app-server.git

2. **Navigate to the server directory:**

   cd chat-app-server

3. **Install dependencies:**

Use Dart’s package manager to install necessary packages:
-> dart pub get

4. **Run the server:**

You can start the Dart server using the following command:
-> dart run bin/server.dart

5. **Configure the client:**
   -> Make sure the Flutter client is configured to connect to the server's IP address and port.
