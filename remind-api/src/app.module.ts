import { Module } from '@nestjs/common';
import { AuthModule } from '@thallesp/nestjs-better-auth';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { auth } from './lib/auth';
import { LocationModule } from './location/location.module';
import { SafeZoneModule } from './safezone/safezone.module';

@Module({
  imports: [AuthModule.forRoot({ auth }), LocationModule, SafeZoneModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
