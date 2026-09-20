/// All WindBlog Admin SeeRay development settings live in this file.
///
/// Keep the site ID and collector origin here so changing the development
/// environment does not require searching through application pages. The
/// loopback HTTP exception is intentionally enabled only for local development.
class WindBlogSeeRayConfig {
  const WindBlogSeeRayConfig._();

  static const enabled = true;
  static const apiOrigin = 'http://localhost:8080';
  static const siteId = 'srl_tlbehkdf9R8bhJlsRk2JGkzkrkJK4hXj';
  static const appOrigin = 'http://localhost:3000';
  static const requireConsent = false;
  static const allowInsecureLocalhost = true;
}
