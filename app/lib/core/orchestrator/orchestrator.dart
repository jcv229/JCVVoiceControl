import '../nlu/intent.dart';
import '../../features/calls/call_service.dart';
import '../../features/contacts/contact_service.dart';
import '../../features/sms/sms_service.dart';
import '../../features/whatsapp/whatsapp_service.dart';
import '../../features/perception/perception_service.dart';
import '../../features/media/media_service.dart';
import '../../features/navigation/navigation_service.dart';
import '../../features/permissions/permissions_service.dart';
import '../../features/system/system_service.dart';
import '../../features/emergency/emergency_service.dart';

/// Orchestrateur : reçoit une intention et la transmet au service concerné.
///
/// Chaque fonction retourne un texte que l'assistant prononce ensuite à voix
/// haute (synthèse vocale). Cette architecture sépare clairement :
/// compréhension (NLU) -> orchestration -> action -> retour vocal.
class Orchestrator {
  final CallService _calls = CallService();
  final ContactService _contacts = ContactService();
  final SmsService _sms = SmsService();
  final WhatsAppService _whatsapp = WhatsAppService();
  final PerceptionService _perception = PerceptionService();
  final DocumentService _documents = DocumentService();
  final MediaService _media = MediaService();
  final VideoService _video = VideoService();
  final NavigationService _navigation = NavigationService();
  final PermissionsService _permissions = PermissionsService();
  final SystemService _system = SystemService();
  final EmergencyService _emergency = EmergencyService();

  /// Traite une intention et retourne le texte à prononcer.
  Future<String> handle(Intent intent) async {
    switch (intent.type) {
      case IntentType.call:
        return _calls.handle(intent);
      case IntentType.defineContact:
        return _contacts.handleDefine(intent);
      case IntentType.listContacts:
        return _contacts.handleList();
      case IntentType.deleteContact:
        return _contacts.handleDelete(intent);
      case IntentType.sendSms:
        return _sms.handleSend(intent);
      case IntentType.readSms:
        return _sms.handleRead();
      case IntentType.whatsappSend:
        return _whatsapp.handleSend(intent);
      case IntentType.whatsappRead:
        return _whatsapp.handleRead();
      case IntentType.navigate:
        return _navigation.handle(intent);
      case IntentType.listPermissions:
        return _permissions.handleList(intent);
      case IntentType.explainPermission:
        return _permissions.handleExplain(intent);
      case IntentType.readScreen:
        return _system.handleReadScreen();
      case IntentType.playMusic:
        return _media.handlePlay();
      case IntentType.pauseMusic:
        return _media.handlePause();
      case IntentType.resumeMusic:
        return _media.handleResume();
      case IntentType.nextTrack:
        return _media.handleNext();
      case IntentType.previousTrack:
        return _media.handlePrevious();
      case IntentType.volumeUp:
        return _system.handleVolumeUp();
      case IntentType.volumeDown:
        return _system.handleVolumeDown();
      case IntentType.volumeSet:
        return _system.handleVolumeSet(intent);
      case IntentType.torchOn:
        return _system.handleTorchOn();
      case IntentType.torchOff:
        return _system.handleTorchOff();
      case IntentType.battery:
        return _system.handleBattery();
      case IntentType.sos:
        return _emergency.handleSos();
      case IntentType.readDocument:
        return _documents.handleReadDocument();
      case IntentType.ocr:
        return _perception.handleOcr();
      case IntentType.takePhoto:
        return _perception.handleTakePhoto();
      case IntentType.describeImage:
        return _perception.handleDescribeImage();
      case IntentType.openSetting:
        return _system.handleOpenSetting(intent);
      case IntentType.openYoutube:
        return 'Fonction YouTube : j\'ouvrirai YouTube pour rechercher une vidéo. '
            'Cette fonction est en ligne.';
      case IntentType.playVideo:
        return _video.handlePlay();
      case IntentType.readEmail:
        return 'Fonction Gmail : je lirai vos e-mails. '
            'Les messages déjà téléchargés sont lisibles hors ligne.';
      case IntentType.help:
        return _helpText();
      case IntentType.unknown:
      default:
        return 'Je n\'ai pas compris. Dites : aide, pour connaître les commandes.';
    }
  }

  String _helpText() {
    return 'Voici ce que je peux faire : '
        'définir un contact avec un numéro, '
        'appeler un contact, envoyer ou lire des SMS, '
        'envoyer ou lire des messages WhatsApp, '
        'vous guider vers un lieu, '
        'lire l\'écran, '
        'jouer de la musique ou une vidéo, '
        'régler le volume, allumer la lampe torche, '
        'lire votre batterie, '
        'lire des documents ou des textes avec la caméra, '
        'et envoyer une alerte d\'urgence à vos contacts.';
  }
}
