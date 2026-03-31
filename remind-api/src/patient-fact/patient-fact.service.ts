import { Injectable } from '@nestjs/common';
import { db } from '../db';

@Injectable()
export class PatientFactService {
  async create(data: {
    patientId: string;
    category: string;
    label: string;
    value: string;
  }) {
    await db
      .insertInto('patientFact')
      .values({
        patientId: data.patientId,
        category: data.category,
        label: data.label,
        value: data.value,
      })
      .execute();

    return { success: true };
  }

  async findAll(patientId: string) {
    return db
      .selectFrom('patientFact')
      .selectAll()
      .where('patientId', '=', patientId)
      .orderBy('category', 'asc')
      .orderBy('createdAt', 'asc')
      .execute();
  }

  async update(
    id: string,
    data: Partial<{
      category: string;
      label: string;
      value: string;
    }>,
  ) {
    const fact = await db
      .selectFrom('patientFact')
      .select(['patientId'])
      .where('id', '=', id)
      .executeTakeFirst();

    const updateData: Record<string, any> = { updatedAt: new Date() };

    if (data.category !== undefined) updateData.category = data.category;
    if (data.label !== undefined) updateData.label = data.label;
    if (data.value !== undefined) updateData.value = data.value;

    await db
      .updateTable('patientFact')
      .set(updateData)
      .where('id', '=', id)
      .execute();

    return { success: true, patientId: fact?.patientId };
  }

  async remove(id: string) {
    const fact = await db
      .selectFrom('patientFact')
      .select(['patientId'])
      .where('id', '=', id)
      .executeTakeFirst();

    await db.deleteFrom('patientFact').where('id', '=', id).execute();
    return { success: true, patientId: fact?.patientId };
  }
}
