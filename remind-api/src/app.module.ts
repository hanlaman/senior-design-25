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

@Module({
  imports: [
    AuthModule.forRoot({ auth }),
    LocationModule,
    SafeZoneModule,
    ReminderModule,
    ApnsModule,
    ConversationModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
