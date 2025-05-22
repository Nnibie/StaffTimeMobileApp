const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Create the Cloud Function with configuration
exports.checkAdminExists = onCall({
  memory: "256MiB",
  timeoutSeconds: 60,
}, (request) => {
  const {data} = request;

  // Extract phone number from data
  const phone = data && typeof data === "object" ? data.phoneNumber : null;

  // Validate phone parameter
  if (!phone || typeof phone !== "string") {
    throw new Error("Valid phone number is required");
  }

  // Normalize phone number
  let normalizedPhone = String(phone).trim();

  // Ensure phone is in E.164 format with Ghana country code
  if (!normalizedPhone.startsWith("+")) {
    normalizedPhone = "+" + normalizedPhone;
  }

  // Normalize Ghana phone number
  if (!normalizedPhone.startsWith("+233")) {
    if (normalizedPhone.startsWith("+0")) {
      normalizedPhone = "+233" + normalizedPhone.substring(2);
    } else {
      const digits = normalizedPhone.substring(1); // Remove the +
      if (digits.startsWith("233")) {
        normalizedPhone = "+" + digits;
      } else if (digits.startsWith("0")) {
        normalizedPhone = "+233" + digits.substring(1);
      } else {
        normalizedPhone = "+233" + digits;
      }
    }
  }

  // Check if the admin exists in the Admins collection
  return admin
      .firestore()
      .collection("Admins")
      .doc(normalizedPhone)
      .get()
      .then((adminDoc) => {
        if (adminDoc.exists) {
          return {exists: true};
        }

        // Try alternative format without + prefix
        const phoneWithoutPlus = normalizedPhone.substring(1);
        return admin
            .firestore()
            .collection("Admins")
            .doc(phoneWithoutPlus)
            .get();
      })
      .then((altAdminDoc) => {
        if (altAdminDoc && altAdminDoc.exists) {
          return {exists: true};
        }
        return {exists: false};
      })
      .catch((error) => {
      // Log only the error message
        console.error(
            "Error in checkAdminExists:",
            error.message || error.toString(),
        );

        throw new Error("Admin lookup failed. Please try again.");
      });
});
