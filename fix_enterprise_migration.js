/**
 * Enterprise Migration Script for LogiTech
 * 
 * Usage:
 *   1. Ensure serviceAccountKey.json is placed in the project root or GOOGLE_APPLICATION_CREDENTIALS is set.
 *   2. Run: node fix_enterprise_migration.js
 * 
 * What it does:
 *   - Auto-creates default Enterprise ("Mon Entreprise") for existing users in `enterprises` collection.
 *   - Updates `users` collection documents with enterprise membership & currentEnterpriseId.
 *   - Batch updates (500 docs/batch) all 28 Firestore collections to add `enterprise_id`.
 */

const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
let serviceAccount;
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

if (fs.existsSync(serviceAccountPath)) {
  serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} else {
  admin.initializeApp({
    credential: admin.credential.applicationDefault()
  });
}

const db = admin.firestore();

const COLLECTIONS = [
  'invoices',
  'customers',
  'clients',
  'quotes',
  'customer_orders',
  'delivery_notes',
  'return_notes',
  'credit_notes',
  'bons_sortie',
  'stock_entries',
  'stock_transfers',
  'inventory_sheets',
  'receiving_vouchers',
  'purchase_invoices',
  'supplier_returns',
  'supplier_orders',
  'supplier_credit_notes',
  'stock_movements',
  'projects',
  'products',
  'suppliers',
  'fournisseurs',
  'transactions',
  'check_traites',
  'payment_accounts',
  'product_families',
  'warehouses',
  'treasury_accounts',
  'payments',
  'company_settings',
  'document_templates'
];

async function runMigration() {
  console.log('🚀 Starting Enterprise Migration Script...');
  const now = new Date().toISOString();

  // 1. Process Users & Default Enterprises
  console.log('\n--- Phase 1: User & Enterprise Setup ---');
  let authUsers = [];
  try {
    const listUsersResult = await admin.auth().listUsers(1000);
    authUsers = listUsersResult.users;
    console.log(`Found ${authUsers.length} user(s) in Firebase Auth.`);
  } catch (err) {
    console.warn('⚠️ Could not list auth users (ignoring if using emulator):', err.message);
  }

  const userEnterpriseMap = new Map(); // uid -> enterpriseId

  for (const user of authUsers) {
    const uid = user.uid;
    const userDocRef = db.collection('users').doc(uid);
    const userDoc = await userDocRef.get();

    let enterpriseId;

    if (userDoc.exists && userDoc.data().currentEnterpriseId) {
      enterpriseId = userDoc.data().currentEnterpriseId;
      console.log(`User ${uid} already has enterprise: ${enterpriseId}`);
    } else {
      // Create new enterprise for user
      enterpriseId = uuidv4();
      const entRef = db.collection('enterprises').doc(enterpriseId);
      await entRef.set({
        name: 'Mon Entreprise',
        description: 'Entreprise par défaut',
        owner_id: uid,
        members: [{ uid: uid, role: 'admin' }],
        created_at: now,
        updated_at: now
      });

      await userDocRef.set({
        email: user.email,
        enterprises: [enterpriseId],
        currentEnterpriseId: enterpriseId,
        created_at: now,
        updated_at: now
      }, { merge: true });

      console.log(`Created default enterprise ${enterpriseId} for user ${uid}`);
    }

    userEnterpriseMap.set(uid, enterpriseId);
  }

  // Fallback default enterprise for unowned documents
  let fallbackEnterpriseId;
  if (userEnterpriseMap.size > 0) {
    fallbackEnterpriseId = userEnterpriseMap.values().next().value;
  } else {
    fallbackEnterpriseId = uuidv4();
    await db.collection('enterprises').doc(fallbackEnterpriseId).set({
      name: 'Mon Entreprise (Global)',
      description: 'Entreprise par défaut pour documents existants',
      owner_id: 'system',
      members: [],
      created_at: now,
      updated_at: now
    });
    console.log(`Created global fallback enterprise ${fallbackEnterpriseId}`);
  }

  // 2. Add enterprise_id to all Collections
  console.log('\n--- Phase 2: Updating Documents in Collections ---');

  for (const colName of COLLECTIONS) {
    console.log(`Processing collection: ${colName}...`);
    try {
      const snapshot = await db.collection(colName).get();
      if (snapshot.empty) {
        console.log(`  Collection ${colName} is empty, skipping.`);
        continue;
      }

      let updatedCount = 0;
      let batch = db.batch();
      let batchCount = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();

        if (!data.enterprise_id) {
          // Determine enterprise_id (from firebase_uid if available, otherwise fallback)
          let assignedEntId = fallbackEnterpriseId;
          if (data.firebase_uid && userEnterpriseMap.has(data.firebase_uid)) {
            assignedEntId = userEnterpriseMap.get(data.firebase_uid);
          }

          batch.update(doc.ref, {
            enterprise_id: assignedEntId,
            updated_at: data.updated_at || now
          });

          batchCount++;
          updatedCount++;

          if (batchCount === 500) {
            await batch.commit();
            console.log(`  Committed batch of 500 docs for ${colName}`);
            batch = db.batch();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      console.log(`  ✅ ${colName}: updated ${updatedCount} / ${snapshot.docs.length} documents.`);
    } catch (err) {
      console.error(`  ❌ Error processing collection ${colName}:`, err.message);
    }
  }

  console.log('\n🎉 Enterprise Migration Complete!');
  process.exit(0);
}

runMigration().catch(err => {
  console.error('Fatal Migration Error:', err);
  process.exit(1);
});
