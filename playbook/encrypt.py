import sys
from nacl.public import PublicKey, SealedBox
from base64 import b64decode, b64encode

if len(sys.argv) != 3:
    print("Usage: encrypt_message.py <public_key_base64> <message>")
    sys.exit(1)

# Lire les arguments
base64_public_key = sys.argv[1]
message = sys.argv[2].encode('utf-8')

# Décoder la clé publique
decoded_public_key = b64decode(base64_public_key)
public_key = PublicKey(decoded_public_key)

# Créer une boîte scellée pour le chiffrement
sealed_box = SealedBox(public_key)

# Chiffrer le message
encrypted_message = sealed_box.encrypt(message)

# Convertir le message chiffré en Base64
encrypted_message_base64 = b64encode(encrypted_message).decode('utf-8')

# Afficher le message chiffré
print(encrypted_message_base64)