#!/usr/bin/env python3

"""
Signal Desktop Database Extractor - Final Version
Works with decrypted Signal Desktop database
"""

import json
import os
import sqlite3
import sys

# Locations of things
BASE = os.path.dirname(os.path.abspath(__file__))
DB = "desktop_messages.db"

if not os.path.exists(DB):
    print(f"Error: {DB} not found in current directory!")
    print(f"First extract the database using:")
    print(f"  signalbackup-tools --desktopdir /path/to/Signal --dumpdesktopdb desktop_messages.db")
    sys.exit(1)

# Connect to the decrypted database
db = sqlite3.connect(DB)
db.row_factory = sqlite3.Row  # Access columns by name
c = db.cursor()
c2 = db.cursor()

# Hold numeric user id to conversation/user names
conversations = {}

# Hold message body data
convos = {}

print("Extracting conversations...")
c.execute("SELECT json, id, name, profileName, type, members FROM conversations")
for result in c:
    cId = result['id']
    isGroup = result['type'] == "group"

    # Parse JSON field if it exists
    json_data = {}
    if result['json']:
        try:
            json_data = json.loads(result['json'])
        except:
            pass

    conversations[cId] = {
        "id": cId,
        "name": result['name'] or json_data.get('name'),
        "profileName": result['profileName'] or json_data.get('profileName'),
        "isGroup": isGroup
    }
    convos[cId] = []

    if isGroup and result['members']:
        usableMembers = []
        # Attempt to match group members from ID (phone number) back to real
        # names if the real names are also in your contact/conversation list.
        members_list = result['members'].split() if result['members'] else []

        for member in members_list:
            c2.execute(
                "SELECT name, profileName FROM conversations WHERE id=?",
                [member])
            name_result = c2.fetchone()
            if name_result:
                useName = name_result['name'] or name_result['profileName'] or member
                usableMembers.append(useName)
            else:
                usableMembers.append(member)

        conversations[cId]["members"] = usableMembers

print(f"Found {len(conversations)} conversations")

print("Extracting messages...")
# We either need an ORDER BY or a manual sort() below because our web interface
# processes message history in array order with javascript object traversal.
c.execute(
    "SELECT id, json, conversationId, sent_at, received_at, body, type, hasAttachments FROM messages ORDER BY sent_at")

message_count = 0
for result in c:
    cId = result['conversationId']
    if not cId:
        # Signal's data model isn't as stable as one would imagine
        continue

    # Build message object from both json and column fields
    try:
        # Start with JSON data (contains metadata like send states, timestamps, etc.)
        content = {}
        if result['json']:
            content = json.loads(result['json'])

        # Add essential fields from columns (these are what the HTML viewer needs)
        content['body'] = result['body']
        content['type'] = result['type']
        content['sent_at'] = result['sent_at']
        content['received_at'] = result['received_at']
        content['id'] = result['id']

        # Fetch attachments for this message
        attachments = []
        if result['hasAttachments']:
            c2.execute("""
                SELECT contentType, path, fileName, caption, width, height, size, blurHash
                FROM message_attachments
                WHERE messageId = ? AND attachmentType = 'attachment'
                ORDER BY orderInMessage
            """, [result['id']])

            for att_row in c2:
                attachment = {
                    'contentType': att_row['contentType'],
                    'fileName': att_row['fileName'],
                    'size': att_row['size']
                }

                # Add path if available
                if att_row['path']:
                    attachment['path'] = att_row['path']

                # Add thumbnail info for images/videos
                if att_row['width'] and att_row['height']:
                    attachment['width'] = att_row['width']
                    attachment['height'] = att_row['height']

                    # Create thumbnail structure expected by HTML viewer
                    if att_row['blurHash'] or att_row['path']:
                        attachment['thumbnail'] = {
                            'path': att_row['path'],
                            'width': att_row['width'],
                            'height': att_row['height']
                        }

                if att_row['caption']:
                    attachment['caption'] = att_row['caption']

                attachments.append(attachment)

        content['attachments'] = attachments
        convos[cId].append(content)
        message_count += 1
    except (json.JSONDecodeError, KeyError, TypeError) as e:
        # Skip malformed messages
        continue

print(f"Extracted {message_count} messages")

print("Writing output files...")
# Exporting JSON to files is optional since we also paste it directly
# into the resulting HTML interface
with open("contacts.json", "w") as con:
    json.dump(conversations, con, indent=2)
    # Use ensure_ascii=True to escape unicode and special chars for safe HTML embedding
    contactsJSON = json.dumps(conversations, ensure_ascii=True)

with open("convos.json", "w") as ampc:
    json.dump(convos, ampc, indent=2)
    # Use ensure_ascii=True to escape unicode and special chars for safe HTML embedding
    convosJSON = json.dumps(convos, ensure_ascii=True)

# Escape any potential </script> tags in the JSON that could break HTML
contactsJSON = contactsJSON.replace("</", "<\\/")
convosJSON = convosJSON.replace("</", "<\\/")

# Create end result of interactive HTML interface with embedded and formatted
# chat history for all contacts/conversations.
chattr_path = f"{BASE}/chattr.html"
if not os.path.exists(chattr_path):
    chattr_path = "../chattr.html"  # Try parent directory

if not os.path.exists(chattr_path):
    print(f"\nWarning: chattr.html template not found!")
    print("JSON files have been created: contacts.json and convos.json")
else:
    with open(chattr_path, "r") as chattr:
        newChat = chattr.read()
        updated = newChat.replace(
            "JSONINSERTHERE",
            f"var contacts = {contactsJSON}; var convos = {convosJSON};")

        with open("myConversations.html", "w") as mine:
            mine.write(updated)

    print("\nDone! Output files:")
    print("  - contacts.json")
    print("  - convos.json")
    print("  - myConversations.html")
    print("\nOpen myConversations.html in your browser to view your conversations.")

db.close()
