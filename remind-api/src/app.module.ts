import { Module } from '@nestjs/common';
import { AuthModule } from '@thallesp/nestjs-better-auth';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { auth } from './lib/auth';
import { LocationModule } from './location/location.module';
import { SafeZoneModule } from './safezone/safezone.module';
import { ReminderModule } from './reminder/reminder.module';
import { ApnsModule } from './apns/apns.module';
import { ConversationModule } from './conversation/conversation.module';
import { MemoryModule } from './memory/memory.module';

@Module({
  imports: [
    AuthModule.forRoot({ auth }),
    LocationModule,
    SafeZoneModule,
    ReminderModule,
    ApnsModule,
    ConversationModule,
    MemoryModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
