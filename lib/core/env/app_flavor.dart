enum AppFlavor { dev, prod }

AppFlavor parseFlavor(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'dev':
    case 'development':
      return AppFlavor.dev;
    case 'prod':
    case 'production':
    default:
      return AppFlavor.prod;
  }
}
