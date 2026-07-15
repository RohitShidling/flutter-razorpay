import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/theme/app_theme.dart';

class LegalScreen extends StatelessWidget {
  final int initialTabIndex;

  const LegalScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Legal Information',
            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
          ),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: const [
              Tab(text: 'Terms'),
              Tab(text: 'Privacy'),
              Tab(text: 'Refunds'),
              Tab(text: 'Shipping/Delivery'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _buildTermsTab(context, isDark),
              _buildPrivacyTab(context, isDark),
              _buildRefundTab(context, isDark),
              _buildShippingTab(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefundTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildDocumentHeader(
          title: 'Return & Refund Policy',
          lastUpdated: 'July 10, 2026',
          version: 'v1.1',
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: '1. Same-Day Returns & Exchanges',
          content: 'At Buuttii, we take great pride in the quality and freshness of our food. If you are not entirely satisfied with your meal, we are here to help make it right.\n\nBecause our products are freshly prepared and perishable, we accept return and exchange requests on the same day of delivery only.\n\nYou can request a return or exchange if:\n• The food quality does not meet our standards.\n• You receive the wrong item or have any other issue with your order.\n\nYour Options:\n• Instant Exchange: We will gladly replace the food and deliver a fresh order to you on the same day at no extra cost.\n• Full/Partial Refund: If you prefer not to have an exchange, we will initiate a refund for the problematic items.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '2. How to Request a Return',
          content: 'To report an issue with your food, please contact us immediately on the same day you receive your order:\n• Call/WhatsApp: 7090115155\n• Email: buuttimeals@gmail.com\n\nNote: We may ask for a quick photo of the food to help our kitchen team understand what went wrong and improve our service.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '3. Refund Process & Timeline',
          content: 'Once your refund request is approved by our team:\n• The refund will be automatically processed back to your original payment method.\n• It will take 5 to 7 working days for the credited amount to reflect in your bank account or card statement, depending on your financial institution.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '4. Contact Us',
          content: 'If you have any questions about your order or need immediate assistance with a meal you just received, please reach out to our customer support team right away. We are dedicated to ensuring you have a delicious experience!',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTermsTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildDocumentHeader(
          title: 'Terms & Conditions',
          lastUpdated: 'July 6, 2026',
          version: 'v1.0',
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Electronic Record',
          content: 'This document is an electronic record in terms of the Information Technology Act, 2000 and rules thereunder as applicable, and the amended provisions pertaining to electronic records in various statutes as amended by the Information Technology Act, 2000. This electronic record is generated by a computer system and does not require any physical or digital signatures.\n\nThis document is published in accordance with the provisions of Rule 3(1) of the Information Technology (Intermediaries Guidelines) Rules, 2011 that require publishing the rules and regulations, privacy policy and Terms of Use for access or usage of the domain name https://buuttii.com/ (\'Website\'), including the related mobile site and mobile application (hereinafter referred to as \'Platform\').',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Platform & Owner',
          content: 'The Platform is owned and operated by Buuttii, based in Hubballi, Karnataka, India with its office at Ashok Nagar, Keshav Nivas, Hubballi, Karnataka, India (hereinafter referred to as \'Platform Owner\', \'we\', \'us\', \'our\').\n\nYour use of the Platform and services and tools are governed by the following Terms of Use as applicable to the Platform, including the applicable policies which are incorporated herein by way of reference. If you transact on the Platform, you shall be subject to the policies applicable to the Platform for such transaction. By mere use of the Platform, you shall be contracting with the Platform Owner and these Terms of Use constitute your binding obligations with the Platform Owner.\n\nThese Terms of Use can be modified at any time without assigning any reason. It is your responsibility to periodically review these Terms of Use to stay informed of updates.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Terms of Use',
          content: 'The use of the Platform and/or availing of our Services is subject to the following terms:\n\n'
              '1. To access and use the Services, you agree to provide true, accurate and complete information to us during and after registration, and you shall be responsible for all acts done through the use of your registered account on the Platform.\n\n'
              '2. Neither we nor any third parties provide any warranty or guarantee as to the accuracy, timeliness, performance, completeness or suitability of the information and materials offered on this website or through the Services, for any specific purpose. You acknowledge that such information and materials may contain inaccuracies or errors and we expressly exclude liability for any such inaccuracies or errors to the fullest extent permitted by law.\n\n'
              '3. Your use of our Services and the Platform is solely and entirely at your own risk and discretion for which we shall not be liable to you in any manner. You are required to independently assess and ensure that the Services meet your requirements.\n\n'
              '4. The contents of the Platform and the Services are proprietary to us and are licensed to us. You will not have any authority to claim any intellectual property rights, title, or interest in its contents. The contents include and are not limited to the design, layout, look and graphics.\n\n'
              '5. You acknowledge that unauthorized use of the Platform and/or the Services may lead to action against you as per these Terms of Use and/or applicable laws.\n\n'
              '6. You agree to pay us the charges associated with availing the Services.\n\n'
              '7. You agree not to use the Platform and/or Services for any purpose that is unlawful, illegal or forbidden by these Terms, or Indian or local laws that might apply to you.\n\n'
              '8. You agree and acknowledge that the website and the Services may contain links to other third-party websites. On accessing these links, you will be governed by the terms of use, privacy policy and such other policies of such third-party websites. These links are provided for your convenience to provide further information.\n\n'
              '9. You understand that upon initiating a transaction for availing the Services you are entering into a legally binding and enforceable contract with the Platform Owner for the Services.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'User Obligations & Acceptable Use',
          content: 'By accessing the Platform, users expressly agree to the following obligations:\n\n'
              '• Not to engage in any activity that interferes with or disruptions the Platform or Services.\n'
              '• Not to attempt unauthorized access to any part of the Platform or related systems.\n'
              '• Not to use the Platform for fraudulent, unlawful, or malicious purposes.\n'
              '• Not to distribute malicious software, spam, or harmful content via the Platform.\n'
              '• To use the Platform only for personal, non-commercial purposes unless expressly permitted.\n'
              '• To not reproduce, duplicate, copy, sell or resell any part of the Platform without our prior written consent.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Liability & Indemnity',
          content: 'You shall indemnify and hold harmless Buuttii, its affiliates, group companies (as applicable) and their respective officers, directors, agents, and employees, from any claim or demand, or actions including reasonable attorney\'s fees, made by any third party or penalty imposed due to or arising out of your breach of these Terms of Use, Privacy Policy and other Policies, or your violation of any law, rules or regulations or the rights (including infringement of intellectual property rights) of a third party.\n\n'
              'Notwithstanding anything contained in these Terms of Use, the parties shall not be liable for any failure to perform an obligation under these Terms if performance is prevented or delayed by a force majeure event.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Governing Law & Jurisdiction',
          content: 'These Terms and any dispute or claim relating to it, or its enforceability, shall be governed by and construed in accordance with the laws of India. All disputes arising out of or in connection with these Terms shall be subject to the exclusive jurisdiction of the courts in Hubballi, Karnataka, India.\n\n'
              'All concerns or communications relating to these Terms must be communicated to us using the contact information provided on this website.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Contact Us',
          content: 'For any grievances or queries related to these Terms of Use, please contact:\n\n'
              '• Brand Owner: Buuttii\n'
              '• Address: Ashok Nagar, Keshav Nivas, Hubballi, Karnataka, India\n'
              '• Email: contact@buuttii.com\n'
              '• Phone: +91 7090115155 (Monday – Friday, 9:00 AM – 6:00 PM)',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPrivacyTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildDocumentHeader(
          title: 'Privacy Policy',
          lastUpdated: 'July 6, 2026',
          version: 'v1.0',
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Introduction',
          content: 'This Privacy Policy describes how Buuttii and its affiliates (collectively "Buuttii, we, our, us") collect, use, share, protect or otherwise process your information/personal data through our website https://buuttii.com/ (hereinafter referred to as Platform).\n\nBy visiting this Platform, providing your information or availing any product/service offered on the Platform, you expressly agree to be bound by the terms and conditions of this Privacy Policy, the Terms of Use and the applicable service/product terms and conditions, and agree to be governed by the laws of India including but not limited to the laws applicable to data protection and privacy. If you do not agree, please do not use or access our Platform.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Collection of Data',
          content: 'We collect your personal data when you use our Platform, services or otherwise interact with us during the course of our relationship. Some of the information that we may collect includes but is not limited to personal data/information provided to us during sign-up/registering or using our Platform such as name, date of birth, address, telephone/mobile number, email ID and/or any such information shared as proof of identity or address.\n\n'
              'Some of the sensitive personal data may be collected with your consent, such as your bank account or credit or debit card or other payment instrument information (in order to enable use of certain features when opted for, available on the Platform), all in accordance with applicable law(s). You always have the option to not provide information by choosing not to use a particular service or feature on the Platform.\n\n'
              'We may track your behaviour, preferences, and other information that you choose to provide on our Platform. This information is compiled and analysed on an aggregated basis. We will also collect your information related to your transactions on the Platform and third-party business partner platforms.\n\n'
              'If you receive an email, a call from a person/association claiming to be Buuttii seeking any personal data like debit/credit card PIN, net-banking or mobile banking password, we request you to never provide such information. If you have already revealed such information, report it immediately to an appropriate law enforcement agency.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Usage of Data',
          content: 'We use personal data to provide the services you request. To the extent we use your personal data to market to you, we will provide you the ability to opt-out of such uses. We use your personal data to:\n'
              '• Assist sellers and business partners in handling and fulfilling orders.\n'
              '• Enhance customer experience and resolve disputes.\n'
              '• Troubleshoot problems and inform you about online and offline offers, products, services and updates.\n'
              '• Customise your experience and detect and protect against error, fraud and other criminal activity.\n'
              '• Enforce our terms and conditions and conduct marketing research, analysis and surveys.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Sharing of Data',
          content: 'We do not sell, rent, or share your personal data with third-party advertisers or external marketing agencies. We only share necessary information with trusted partners required to fulfill your services:\n\n'
              '• Payment Gateways: To securely process subscription payments (e.g. Razorpay).\n'
              '• Delivery Personnel: To coordinate daily meal drop-offs at your designated school or workplace.\n'
              '• Legal Compliance: We may disclose personal and sensitive personal data to government agencies or other authorised law enforcement agencies if required to do so by law or in the good faith belief that such disclosure is reasonably necessary to respond to subpoenas, court orders, or other legal process.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Security Precautions',
          content: 'To protect your personal data from unauthorised access or disclosure, loss or misuse we adopt reasonable security practices and procedures. Once your information is in our possession or whenever you access your account information, we adhere to our security guidelines to protect it against unauthorised access and offer the use of a secure server.\n\n'
              'However, the transmission of information is not completely secure for reasons beyond our control. By using the Platform, the users accept the security implications of data transmission over the internet and the World Wide Web which cannot always be guaranteed as completely secure, and therefore, there would always remain certain inherent risks regarding use of the Platform. Users are responsible for ensuring the protection of login and password records for their account.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Data Deletion and Retention',
          content: 'You have an option to delete your account by visiting your profile and settings on our Platform — this action would result in you losing all information related to your account. You may also write to us at the contact information provided below to assist you with these requests.\n\n'
              'We may, in the event of any pending grievance, claims, pending shipments or any other services, refuse or delay deletion of the account. Once the account is deleted, you will lose access to the account. We retain your personal data information for a period no longer than is required for the purpose for which it was collected or as required under any applicable law. However, we may retain data related to you if we believe it may be necessary to prevent fraud or future abuse or for other legitimate purposes. We may continue to retain your data in anonymised form for analytical and research purposes.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Your Rights',
          content: 'You may access, rectify, and update your personal data directly through the functionalities provided on the Platform.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Consent',
          content: 'By visiting our Platform or by providing your information, you consent to the collection, use, storage, disclosure and otherwise processing of your information on the Platform in accordance with this Privacy Policy. If you disclose to us any personal data relating to other people, you represent that you have the authority to do so and to permit us to use the information in accordance with this Privacy Policy.\n\n'
              'You, while providing your personal data over the Platform or any partner platforms or establishments, consent to us (including our other corporate entities, affiliates, lending partners, technology partners, marketing channels, business partners and other third parties) to contact you through SMS, instant messaging apps, call and/or e-mail for the purposes specified in this Privacy Policy.\n\n'
              'You have an option to withdraw your consent that you have already provided by writing to the Grievance Officer at the contact information provided below. Please mention \'Withdrawal of consent for processing personal data\' in your subject line. We may verify such requests before acting on our request. However, please note that your withdrawal of consent will not be retrospective and will be in accordance with the Terms of Use, this Privacy Policy, and applicable laws. In the event you withdraw consent, we reserve the right to restrict or deny the provision of our services for which we consider such information to be necessary.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Changes to this Privacy Policy',
          content: 'Please check our Privacy Policy periodically for changes. We may update this Privacy Policy to reflect changes to our information practices. We may alert/notify you about the significant changes to the Privacy Policy, in the manner as may be required under applicable laws.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: 'Grievance Officer',
          content: 'For any privacy-related queries or grievances, please contact:\n\n'
              '• Brand Owner: Buuttii\n'
              '• Address: Ashok Nagar, Keshav Nivas, Hubballi, Karnataka, India\n'
              '• Email: contact@buuttii.com\n'
              '• Phone: +91 7090115155 | Monday – Friday, 9:00 AM – 6:00 PM',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDocumentHeader({
    required String title,
    required String lastUpdated,
    required String version,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.doc_text_viewfinder,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHeaderBadge('Version $version', isDark),
              const SizedBox(width: 8),
              Text(
                'Updated $lastUpdated',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : AppTheme.textSecondaryLight.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildShippingTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildDocumentHeader(
          title: 'Shipping & Delivery Policy',
          lastUpdated: 'July 10, 2026',
          version: 'v1.1',
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Overview',
          content: 'Thank you for shopping with us! We pride ourselves on providing ultra-fast, local delivery to ensure your items arrive fresh and on time. Please review the details of our delivery policy below.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '1. Delivery Timeline',
          content: '• Hyper-Fast Delivery: Once your order is confirmed, it will be prepared and delivered to your doorstep within 3 to 4 hours.\n• Order Tracking: You will receive an update (via SMS/Email/WhatsApp) as soon as your order is confirmed and when it is out for delivery.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '2. Serviceable Delivery Area',
          content: 'To maintain our speed and quality of service, we operate strictly within a localized zone.\n• We currently only deliver to locations within a 5 to 8 km radius of our store/hub.\n• Checking Eligibility: Please enter your delivery pincode/address at checkout to verify if your location falls within our active service zone. If you are outside this radius, the system will unfortunately not allow you to place a delivery order.',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
