import { Injectable } from '@nestjs/common';
import { db } from '../db';

@Injectable()
export class ContactService {
  async upsert(data: {
    patientId: string;
    role: string;
    name: string;
    phoneNumber: string;
  }) {
    const existing = await db
      .selectFrom('contact')
      .selectAll()
      .where('patientId', '=', data.patientId)
      .where('role', '=', data.role)
      .executeTakeFirst();

    if (existing) {
      await db
        .updateTable('contact')
        .set({
          name: data.name,
          phoneNumber: data.phoneNumber,
          updatedAt: new Date(),
        })
        .where('id', '=', existing.id)
        .execute();

      return { success: true, id: existing.id };
    }

    await db
      .insertInto('contact')
      .values({
        patientId: data.patientId,
        role: data.role,
        name: data.name,
        phoneNumber: data.phoneNumber,
      })
      .execute();

    return { success: true };
  }

  async findAll(patientId: string) {
    return db
      .selectFrom('contact')
      .selectAll()
      .where('patientId', '=', patientId)
      .orderBy('role', 'asc')
      .execute();
  }

  async findByRole(patientId: string, role: string) {
    return db
      .selectFrom('contact')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('role', '=', role)
      .executeTakeFirst();
  }

  async remove(id: string) {
    await db.deleteFrom('contact').where('id', '=', id).execute();
    return { success: true };
  }
}
