Map<dynamic, dynamic> buildPushNotificationMetadataAndroid() {
  return {
    'itbl':
        '{"defaultAction":{"type":"openApp"},"isGhostPush":false,"messageId":"messageIdValue","actionButtons":[],"templateId":10}',
    'source': 'push',
  };
}

Map<dynamic, dynamic> buildPushNotificationMetadataIOS() {
  return {
    'itbl': {
      'messageId': 'messageValue',
      'defaultAction': {'type': 'openApp'},
      'templateId': 10,
      'actionButtons': [],
      'isGhostPush': false
    },
    'source': 'push',
  };
}

Map<dynamic, dynamic> buildPushNotificationMetadataIOSWithQuot() {
  return {
    'itbl':
        '{&quot;defaultAction&quot;:{&quot;type&quot;:&quot;openApp&quot;},&quot;isGhostPush&quot;:false,&quot;messageId&quot;:&quot;messageIdValue&quot;,&quot;actionButtons&quot;:[],&quot;templateId&quot;:10}',
    'source': 'push',
  };
}
