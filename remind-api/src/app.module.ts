import { Module } from '@nestjs/common';
import { AuthModule } from '@thallesp/nestjs-better-auth';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { auth } from './lib/auth';
import { LocationModule } from './location/location.module';

@Module({
  imports: [AuthModule.forRoot({ auth }), LocationModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
