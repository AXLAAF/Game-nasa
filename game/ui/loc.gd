class_name Loc
extends RefCounted

## Traduccion para codigo estatico, donde tr() no existe (solo se puede llamar sobre una instancia).
## Usa el mismo catalogo que tr(): localization/en.po. El texto original del codigo esta en espanol.


static func t(text: String) -> String:
	return String(TranslationServer.translate(text))
