# **Message format**:

---

As following, in the JSON format.

    {
      type: <type{String}>,
      [arguments]
    }

# **Server -> Client Message Types**:

---

### `error` type
Returns an error message.
 - `message` {String} The error message.

### `id` type
Assigns an Client ID to a remote connection.
 - `value` {Number<1-65535>} Client ID assigned to the remote connection.

### `receive` type
Receiving a transmitted message.
 - `channel` {Number<1-65535>} Channel ID which this message was transmitted on.
 - `reply_channel` {Number<1-65535>} The senders designated reply channel.
 - `id` {Number<1-65535>} Client ID which this message was sent from.
 - `message_type` {String[string, number, table]} The messages type.
 - `message` {String} The transmitted message.

# **Client -> Server Message Types**:

---

### `open` type
Opens a channel.
 - `channel` {Number<1-65535>} Channel ID to open.

### `close` type
Closes a channel.
 - `channel` {Number<1-65535>} Channel ID to close.

### `close_all` type
Closes all channels.
 - N/A

### `transmit` type
Transmits a message.
 - `channel` {Number<1-65535>} Channel ID to transmit on.
 - `reply_channel` {Number<1-65535>} The senders designated reply channel.
 - `message_type` {String[string, number, table]} The messages type.
 - `message` {String} Message to transmit.

# **Error Messages**:

---

### `message_too_long`
Your message exceeded the max length.

### `syntax_error`
Your message was invalid JSON.

### `invalid_type`
You did not supply or supplied an invalid message type.

### `invalid_arguments`
You supplied invalid arguments to your specified type.

### `invalid_id`
Your supplied Channel ID exceeded the valid 1-65545 range.

### `already_closed`
The channel you attempted to close was already closed, or never opened.

### `already_open`
The channel you attempted to open was already opened.